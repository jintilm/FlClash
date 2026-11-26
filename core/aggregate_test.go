package core

import (
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/rules"
	"github.com/metacubex/mihomo/tunnel"
)

func TestProviderSnapshotFiltersAndOverridesWithoutApplying(t *testing.T) {
	previous := &config.Config{}
	withCurrentConfig(t, previous)
	result, err := handleProviderSnapshot(ProviderSnapshotParams{
		Definition: map[string]any{
			"type": "inline", "filter": "(?i)keep", "exclude-filter": "drop",
			"override": map[string]any{"additional-prefix": "A-", "udp": true},
			"payload": []map[string]any{
				{"name": "KEEP", "type": "socks5", "server": "192.0.2.1", "port": 1080},
				{"name": "keep-drop", "type": "socks5", "server": "192.0.2.2", "port": 1080},
				{"name": "other", "type": "socks5", "server": "192.0.2.3", "port": 1080},
			},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(result) != 1 || result[0]["name"] != "A-KEEP" || result[0]["udp"] != true {
		t.Fatalf("unexpected snapshot: %#v", result)
	}
	if currentConfig != previous {
		t.Fatal("snapshot changed running config")
	}
}

func aggregateConnectServer(t *testing.T, targets chan<- string) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect {
			http.Error(w, "CONNECT required", 405)
			return
		}
		upstream, err := net.DialTimeout("tcp", r.Host, time.Second)
		if err != nil {
			http.Error(w, err.Error(), 502)
			return
		}
		defer upstream.Close()
		client, buffered, err := w.(http.Hijacker).Hijack()
		if err != nil {
			return
		}
		defer client.Close()
		targets <- r.Host
		_, _ = client.Write([]byte("HTTP/1.1 200 Connection established\r\n\r\n"))
		done := make(chan struct{})
		go func() { _, _ = io.Copy(upstream, buffered); upstream.Close(); close(done) }()
		_, _ = io.Copy(client, upstream)
		client.Close()
		<-done
	}))
	t.Cleanup(server.Close)
	return server
}

func TestAggregateTwoHopRouteConnectsInEntryExitOrder(t *testing.T) {
	entryTargets, exitTargets := make(chan string, 4), make(chan string, 4)
	entryServer := aggregateConnectServer(t, entryTargets)
	exitServer := aggregateConnectServer(t, exitTargets)
	destination := probeServer(t, func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("exit reached")) })
	makeProxy := func(name string, server *httptest.Server, dialer string) constant.Proxy {
		host, port, _ := net.SplitHostPort(server.Listener.Addr().String())
		number, _ := strconv.Atoi(port)
		mapping := map[string]any{"name": name, "type": "http", "server": host, "port": number}
		if dialer != "" {
			mapping["dialer-proxy"] = dialer
		}
		proxy, err := adapter.ParseProxy(mapping, adapter.WithTunnelForAPI(tunnel.Tunnel))
		if err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { proxy.Close() })
		return proxy
	}
	entry, exit := makeProxy("aggregate-entry", entryServer, ""), makeProxy("aggregate-exit", exitServer, "aggregate-entry")
	pool := selectorOver(t, "Aggregate", entry, exit)
	target := selectorOver(t, "Proxy", entry, pool)
	global := selectorOver(t, "GLOBAL", entry, pool)
	tunnel.UpdateProxies(map[string]constant.Proxy{
		"aggregate-entry": entry, "aggregate-exit": exit,
		"Aggregate": pool, "Proxy": target, "GLOBAL": global,
	}, nil)
	t.Cleanup(func() { tunnel.UpdateProxies(nil, nil) })
	result := runProbe(context.Background(), probeRequest{url: destination.URL, proxyName: "aggregate-exit", timeout: 3 * time.Second, maxBody: 64})
	if result == nil || result.Error != "" || result.Body != "exit reached" {
		t.Fatalf("route failed: %+v", result)
	}
	select {
	case target := <-entryTargets:
		if target != exitServer.Listener.Addr().String() {
			t.Fatalf("entry dialed %q", target)
		}
	default:
		t.Fatal("entry was bypassed")
	}
	select {
	case target := <-exitTargets:
		if target != destination.Listener.Addr().String() {
			t.Fatalf("exit dialed %q", target)
		}
	default:
		t.Fatal("exit was bypassed")
	}
	match, err := rules.ParseRule("MATCH", "", "Proxy", nil, nil)
	if err != nil {
		t.Fatal(err)
	}
	tunnel.UpdateRules([]constant.Rule{match}, nil, nil)
	previousMode := tunnel.Mode()
	tunnel.OnRunning()
	t.Cleanup(func() {
		tunnel.OnSuspend()
		tunnel.SetMode(previousMode)
		tunnel.UpdateRules(nil, nil, nil)
	})
	patchSelectGroup(map[string]string{"Proxy": "Aggregate", "GLOBAL": "Aggregate", "Aggregate": "aggregate-exit"})
	for _, mode := range []tunnel.TunnelMode{tunnel.Rule, tunnel.Global} {
		tunnel.SetMode(mode)
		result = runProbe(context.Background(), probeRequest{url: destination.URL, timeout: 3 * time.Second, maxBody: 64})
		if result == nil || result.Error != "" || result.Body != "exit reached" || len(result.Chains) == 0 || result.Chains[0] != "aggregate-exit" || !slices.Contains(result.Chains, "Aggregate") {
			t.Fatalf("routed probe in %v = %+v", mode, result)
		}
		if len(result.hits) == 0 || result.hits[0].Exit != exitName(exit) {
			t.Fatalf("routed exit in %v = %+v", mode, result.hits)
		}
	}
}

func TestProviderSnapshotReadsManagedCacheAndRejectsInvalidNodes(t *testing.T) {
	previous := constant.Path.HomeDir()
	home := t.TempDir()
	constant.SetHomeDir(home)
	t.Cleanup(func() { constant.SetHomeDir(previous) })
	path := filepath.Join(home, "provider.yaml")
	if err := os.WriteFile(path, []byte("proxies:\n- {name: cached, type: socks5, server: 192.0.2.1, port: 1080}\n"), 0600); err != nil {
		t.Fatal(err)
	}
	result, err := handleProviderSnapshot(ProviderSnapshotParams{Definition: map[string]any{"type": "file", "path": path}})
	if err != nil || len(result) != 1 || result[0]["name"] != "cached" {
		t.Fatalf("%v: %v", result, err)
	}
	_, err = handleProviderSnapshot(ProviderSnapshotParams{Definition: map[string]any{"type": "inline"}, Content: "proxies:\n- {name: bad, type: invalid}\n"})
	if err == nil {
		t.Fatal("invalid proxy accepted")
	}
}

func TestAggregateApplyFailurePreservesRunningConfig(t *testing.T) {
	previousHome := constant.Path.HomeDir()
	home := t.TempDir()
	constant.SetHomeDir(home)
	t.Cleanup(func() { constant.SetHomeDir(previousHome) })
	previous := &config.Config{}
	withCurrentConfig(t, previous)
	if err := os.WriteFile(filepath.Join(home, "config.yaml"), []byte("proxies: invalid"), 0600); err != nil {
		t.Fatal(err)
	}
	err := applyConfig(&SetupParams{PreserveOnFailure: true})
	var methodErr *MethodError
	if !errors.As(err, &methodErr) || methodErr.Code != "config_preserved" {
		t.Fatalf("unexpected failure: %v", err)
	}
	if currentConfig != previous {
		t.Fatal("replaced running config after failure")
	}
}

func TestProviderSnapshotRefreshPreservesCacheUntilValidated(t *testing.T) {
	previous := constant.Path.HomeDir()
	home := t.TempDir()
	constant.SetHomeDir(home)
	t.Cleanup(func() { constant.SetHomeDir(previous) })
	path := filepath.Join(home, "profiles", "providers", "1", "proxies", "cached")
	content := "proxies:\n- {name: cached, type: socks5, server: 192.0.2.1, port: 1080}\n"
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = io.WriteString(w, content) }))
	defer server.Close()
	params := ProviderSnapshotParams{Refresh: true, Definition: map[string]any{"type": "http", "path": path, "url": server.URL}}
	got, err := handleProviderSnapshot(params)
	if err != nil || len(got) != 1 {
		t.Fatalf("first fetch = %v, %v", got, err)
	}
	before, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	content = "proxies:\n- {name: invalid, type: invalid}\n"
	if _, err := handleProviderSnapshot(params); err == nil {
		t.Fatal("invalid update accepted")
	}
	after, err := os.ReadFile(path)
	if err != nil || string(after) != string(before) {
		t.Fatalf("invalid update replaced cache: %q, %v", after, err)
	}
	params.Definition["path"] = filepath.Join(home, "config.yaml")
	if _, err := handleProviderSnapshot(params); err == nil {
		t.Fatal("refresh allowed outside the provider cache")
	}
}
