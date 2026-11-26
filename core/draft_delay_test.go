package core

import (
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/tunnel"
)

func draftHttpNode(server *httptest.Server) map[string]any {
	host, port, _ := net.SplitHostPort(server.Listener.Addr().String())
	number, _ := strconv.Atoi(port)
	return map[string]any{"name": "same-name", "type": "http", "server": host, "port": number}
}

func TestDraftDelayTestsTwoHopsWithoutInstallingProxies(t *testing.T) {
	entryTargets, exitTargets := make(chan string, 8), make(chan string, 8)
	entry := aggregateConnectServer(t, entryTargets)
	exit := aggregateConnectServer(t, exitTargets)
	destination := probeServer(t, func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(204) })
	withProbeProxies(t, "current")
	previous := &config.Config{}
	withCurrentConfig(t, previous)
	before := tunnel.AllProxies()
	entryNode, exitNode := draftHttpNode(entry), draftHttpNode(exit)
	result, err := handleTestDraftDelay(DraftDelayParams{
		Proxies: []map[string]any{entryNode, exitNode}, TestURL: destination.URL, Timeout: 3000,
	})
	if err != nil || result == nil || result.Value < 1 {
		t.Fatalf("delay = %+v, error = %v", result, err)
	}
	select {
	case target := <-entryTargets:
		if target != exit.Listener.Addr().String() {
			t.Fatalf("entry dialed %s", target)
		}
	default:
		t.Fatal("entry bypassed")
	}
	select {
	case target := <-exitTargets:
		if target != destination.Listener.Addr().String() {
			t.Fatalf("exit dialed %s", target)
		}
	default:
		t.Fatal("exit bypassed")
	}
	after := tunnel.AllProxies()
	if currentConfig != previous || len(before) != len(after) || after["current"] != before["current"] {
		t.Fatal("draft test changed running configuration")
	}
	if entryNode["name"] != "same-name" || exitNode["dialer-proxy"] != nil {
		t.Fatal("draft mutated input nodes")
	}
}

func TestDraftDelayTestsSingleNodeAndRejectsExistingDialers(t *testing.T) {
	targets := make(chan string, 8)
	entry := aggregateConnectServer(t, targets)
	destination := probeServer(t, func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(204) })
	node := draftHttpNode(entry)
	params := DraftDelayParams{Proxies: []map[string]any{node}, TestURL: destination.URL, Timeout: 1000}
	result, err := handleTestDraftDelay(params)
	if err != nil || result == nil || result.Value < 1 {
		t.Fatalf("delay = %+v, error = %v", result, err)
	}
	node["dialer-proxy"] = "current"
	if _, err := handleTestDraftDelay(params); err == nil {
		t.Fatal("silently discarded existing dialer")
	}
	if _, err := handleTestDraftDelay(DraftDelayParams{}); err == nil {
		t.Fatal("empty test accepted")
	}
	if len(delayTestSlots) != 0 {
		t.Fatal("test leaked concurrency slot")
	}
}

func TestDraftDelayFailureReleasesItsSlot(t *testing.T) {
	params := DraftDelayParams{Proxies: []map[string]any{{"name": "invalid", "type": "unknown"}}, Timeout: 10}
	if _, err := handleTestDraftDelay(params); err == nil {
		t.Fatal("invalid node accepted")
	}
	if len(delayTestSlots) != 0 {
		t.Fatal("parse failure leaked concurrency slot")
	}
}

func TestDraftDelayTimesOutTheCompleteChain(t *testing.T) {
	targets := make(chan string, 8)
	entry := aggregateConnectServer(t, targets)
	destination := probeServer(t, func(w http.ResponseWriter, r *http.Request) { <-r.Context().Done() })
	result, err := handleTestDraftDelay(DraftDelayParams{
		Proxies: []map[string]any{draftHttpNode(entry)}, TestURL: destination.URL, Timeout: 40,
	})
	if err != nil || result == nil || result.Value != delayTimedOut {
		t.Fatalf("timeout = %+v, %v", result, err)
	}
	if len(delayTestSlots) != 0 {
		t.Fatal("timeout leaked concurrency slot")
	}
}
