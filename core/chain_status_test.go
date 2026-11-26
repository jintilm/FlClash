package core

import (
	"bufio"
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func TestChainStatusMeasuresTheRealEntryTransport(t *testing.T) {
	entryServer := aggregateConnectServer(t, make(chan string, 8))
	exitServer := aggregateConnectServer(t, make(chan string, 8))
	destination := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "through the entry\n")
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	})
	entryNode, exitNode := draftHttpNode(entryServer), draftHttpNode(exitServer)
	entryNode["name"] = "SG [entry:chain]"
	exitNode["name"], exitNode["dialer-proxy"] = "SG to LT", entryNode["name"]
	entry, err := adapter.ParseProxy(entryNode, adapter.WithTunnelForAPI(tunnel.Tunnel))
	if err != nil {
		t.Fatal(err)
	}
	exit, err := adapter.ParseProxy(exitNode, adapter.WithTunnelForAPI(tunnel.Tunnel))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { entry.Close(); exit.Close() })
	group := selectorOver(t, "Proxy", entry, exit)
	tunnel.UpdateProxies(map[string]constant.Proxy{entry.Name(): entry, exit.Name(): exit, "Proxy": group, "GLOBAL": group}, nil)
	previousMode := tunnel.Mode()
	tunnel.SetMode(tunnel.Rule)
	t.Cleanup(func() { tunnel.SetMode(previousMode); tunnel.UpdateProxies(nil, nil) })
	params := ChainStatusParams{Proxy: exit.Name(), Target: "Proxy"}
	before := handleChainStatus(params)
	if before.Selected || before.EntryConnections != 0 || before.Entry != entry.Name() {
		t.Fatalf("before: %+v", before)
	}
	if current := handleChainStatus(ChainStatusParams{Target: "Proxy"}); current.Proxy != entry.Name() || current.Entry != "" || !current.Selected {
		t.Fatalf("single selection: %+v", current)
	}
	patchSelectGroup(map[string]string{"Proxy": exit.Name()})
	selected := handleChainStatus(params)
	if !selected.Selected || selected.EntryConnections != 0 {
		t.Fatalf("selected is not connected: %+v", selected)
	}
	metadata := &constant.Metadata{Type: constant.HTTP, NetWork: constant.TCP}
	if err := metadata.SetRemoteAddress(destination.Listener.Addr().String()); err != nil {
		t.Fatal(err)
	}
	conn, err := exit.DialContext(context.Background(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	tracker := statistic.NewTCPTracker(conn, statistic.DefaultManager, metadata, nil, 0, 0, true)
	t.Cleanup(func() { tracker.Close() })
	tracker.SetDeadline(time.Now().Add(3 * time.Second))
	fmt.Fprintf(tracker, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
	reader := bufio.NewReader(tracker)
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			t.Fatal(err)
		}
		if line == "through the entry\n" {
			break
		}
	}
	active := handleChainStatus(params)
	if !active.Selected || active.EntryConnections != 1 || active.ExitConnections != 1 || active.Upload <= 0 || active.Download <= 0 {
		t.Fatalf("active: %+v", active)
	}
	if current := handleChainStatus(ChainStatusParams{Target: "Proxy"}); current != active {
		t.Fatalf("automatic chain: %+v, pinned: %+v", current, active)
	}
	found := false
	for _, info := range handleGetConnections().Connections {
		if info.Metadata.Type == constant.INNER && len(info.Chain) > 0 && info.Chain[0] == entry.Name() {
			found = true
		}
	}
	if !found {
		t.Fatal("entry transport missing from live connections")
	}
	tunnel.SetMode(tunnel.Direct)
	if status := handleChainStatus(params); status.Selected || status.EntryConnections != 1 {
		t.Fatalf("old connection: %+v", status)
	}
	tracker.Close()
	deadline := time.Now().Add(time.Second)
	for handleChainStatus(params).EntryConnections > 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if status := handleChainStatus(params); status.EntryConnections != 0 || status.ExitConnections != 0 {
		t.Fatalf("closed: %+v", status)
	}
}

func TestChainStatusDoesNotInventAnEntryForAMissingProxy(t *testing.T) {
	withProbeProxies(t, "direct")
	for _, name := range []string{"direct", "missing"} {
		status := handleChainStatus(ChainStatusParams{Proxy: name, Target: "direct"})
		if status.Entry != "" || status.EntryConnections != 0 || (name == "missing" && status.Selected) {
			t.Fatalf("unexpected entry: %+v", status)
		}
	}
}

func TestChainStatusFollowsSingleNodeGlobalAndDirectSelections(t *testing.T) {
	previousMode := tunnel.Mode()
	sg := adapter.NewProxy(outbound.NewDirectWithOption(outbound.DirectOption{Name: "SG"}))
	lt := adapter.NewProxy(outbound.NewDirectWithOption(outbound.DirectOption{Name: "LT"}))
	direct := adapter.NewProxy(outbound.NewDirect())
	group := selectorOver(t, "Proxy", sg, lt)
	global := selectorOver(t, "GLOBAL", lt, sg)
	tunnel.UpdateProxies(map[string]constant.Proxy{"SG": sg, "LT": lt, "DIRECT": direct, "Proxy": group, "GLOBAL": global}, nil)
	t.Cleanup(func() { tunnel.SetMode(previousMode); tunnel.UpdateProxies(nil, nil) })
	server := probeServer(t, func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, "single node\n")
		w.(http.Flusher).Flush()
		<-r.Context().Done()
	})
	metadata := &constant.Metadata{Type: constant.HTTP, NetWork: constant.TCP}
	if err := metadata.SetRemoteAddress(server.Listener.Addr().String()); err != nil {
		t.Fatal(err)
	}
	conn, err := sg.DialContext(context.Background(), metadata)
	if err != nil {
		t.Fatal(err)
	}
	tracker := statistic.NewTCPTracker(conn, statistic.DefaultManager, metadata, nil, 0, 0, true)
	defer tracker.Close()
	tracker.SetDeadline(time.Now().Add(3 * time.Second))
	fmt.Fprint(tracker, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
	reader := bufio.NewReader(tracker)
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			t.Fatal(err)
		}
		if line == "single node\n" {
			break
		}
	}
	tunnel.SetMode(tunnel.Rule)
	status := handleChainStatus(ChainStatusParams{Target: "Proxy"})
	if status.Proxy != "SG" || status.Entry != "" || status.ExitConnections != 1 || status.Upload <= 0 || status.Download <= 0 {
		t.Fatalf("single: %+v", status)
	}
	tunnel.SetMode(tunnel.Global)
	status = handleChainStatus(ChainStatusParams{Target: "Proxy"})
	if status.Proxy != "LT" || status.Target != "GLOBAL" || status.ExitConnections != 0 || status.Upload != 0 {
		t.Fatalf("global carried previous node: %+v", status)
	}
	tunnel.SetMode(tunnel.Direct)
	status = handleChainStatus(ChainStatusParams{Target: "Proxy"})
	if status.Proxy != "DIRECT" || status.ProxyType != "Direct" || status.Entry != "" || status.ExitConnections != 0 {
		t.Fatalf("direct: %+v", status)
	}
}
