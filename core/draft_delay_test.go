package core

import (
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/tunnel"
)

func TestDraftDelayMultiHopRoute(t *testing.T) {
	for _, count := range []int{3, maxAggregateHops} {
		t.Run(fmt.Sprint(count), func(t *testing.T) {
			servers := make([]*httptest.Server, count)
			targets := make([]chan string, count)
			definitions := make([]map[string]any, count)
			for i := range count {
				targets[i] = make(chan string, 8)
				servers[i] = aggregateConnectServer(t, targets[i])
				definitions[i] = draftHttpNode(servers[i])
			}
			destination := probeServer(t, func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(204) })
			result, err := handleTestDraftDelay(DraftDelayParams{Proxies: definitions, TestURL: destination.URL, Timeout: 3000})
			if err != nil || result == nil || result.Value < 1 {
				t.Fatalf("%+v: %v", result, err)
			}
			for i := range count {
				want := destination.Listener.Addr().String()
				if i < count-1 {
					want = servers[i+1].Listener.Addr().String()
				}
				select {
				case target := <-targets[i]:
					if target != want {
						t.Fatalf("hop %d dialed %s, want %s", i+1, target, want)
					}
				default:
					t.Fatalf("hop %d was bypassed", i+1)
				}
			}
		})
	}
}

func TestDraftDelayRejectsRepeatedAndExcessHops(t *testing.T) {
	node := map[string]any{"name": "one", "type": "http", "server": "192.0.2.1", "port": 80}
	renamed := map[string]any{"name": "renamed", "type": "http", "server": "192.0.2.1", "port": 80}
	for _, nodes := range [][]map[string]any{{node, renamed}, make([]map[string]any, maxAggregateHops+1)} {
		if _, err := handleTestDraftDelay(DraftDelayParams{Proxies: nodes}); err == nil {
			t.Fatal("invalid chain accepted")
		}
	}
	if len(delayTestSlots) != 0 {
		t.Fatal("slot leaked")
	}
}

func TestDraftDelayRejectsAnIncompatibleIntermediateTransport(t *testing.T) {
	_, err := handleTestDraftDelay(DraftDelayParams{Proxies: []map[string]any{
		{"name": "entry", "type": "http", "server": "192.0.2.1", "port": 80},
		{"name": "middle", "type": "http", "server": "192.0.2.2", "port": 80},
		{"name": "exit", "type": "hysteria2", "server": "192.0.2.3", "port": 443, "password": "test"},
	}, Timeout: 100})
	if err == nil {
		t.Fatal("UDP transport over TCP-only middle accepted")
	}
	if len(delayTestSlots) != 0 {
		t.Fatal("slot leaked")
	}
}

func TestDraftDelayDoesNotBypassAFailedMiddle(t *testing.T) {
	entry := aggregateConnectServer(t, make(chan string, 8))
	middle := aggregateConnectServer(t, make(chan string, 8))
	exitTargets := make(chan string, 8)
	exit := aggregateConnectServer(t, exitTargets)
	middleNode := draftHttpNode(middle)
	middle.Close()
	destination := probeServer(t, func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(204) })
	result, err := handleTestDraftDelay(DraftDelayParams{Proxies: []map[string]any{draftHttpNode(entry), middleNode, draftHttpNode(exit)}, TestURL: destination.URL, Timeout: 1000})
	if err != nil || result == nil || result.Value >= 0 {
		t.Fatalf("failed middle: %+v, %v", result, err)
	}
	select {
	case <-exitTargets:
		t.Fatal("middle bypassed")
	default:
	}
}

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
