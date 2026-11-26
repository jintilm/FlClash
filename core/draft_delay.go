package core

import (
	"context"
	"crypto/rand"
	"fmt"
	"maps"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/component/proxydialer"
	"github.com/metacubex/mihomo/constant"
)

type DraftDelayParams struct {
	Proxies []map[string]any `json:"proxies"`
	TestURL string           `json:"test-url"`
	Timeout int64            `json:"timeout"`
}

func handleTestDraftDelay(params DraftDelayParams) (*Delay, error) {
	if len(params.Proxies) < 1 || len(params.Proxies) > 2 {
		return nil, fmt.Errorf("a draft test requires one or two nodes")
	}
	for _, mapping := range params.Proxies {
		if dialer, _ := mapping["dialer-proxy"].(string); dialer != "" {
			return nil, fmt.Errorf("draft node already has a dialer dependency")
		}
	}
	timeout := timeoutFromMillis(params.Timeout, defaultDelayTestTimeout)
	if !delayTestSlots.acquireWithin(context.Background(), timeout) {
		return nil, nil
	}
	defer delayTestSlots.release()
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	var previous constant.Proxy
	for index, mapping := range params.Proxies {
		definition := maps.Clone(mapping)
		definition["name"] = "@draft-delay-" + rand.Text()
		var options []adapter.ProxyOption
		if previous != nil {
			options = append(options, adapter.WithDialerForAPI(proxydialer.New(previous, false)))
		}
		proxy, err := adapter.ParseProxy(definition, options...)
		if err != nil {
			return nil, fmt.Errorf("draft hop %d: %w", index+1, err)
		}
		defer proxy.Close()
		if index == 1 && !previous.SupportUDP() {
			switch definition["type"] {
			case "hysteria", "hysteria2", "tuic", "wireguard":
				return nil, fmt.Errorf("entry does not support UDP")
			}
		}
		previous = proxy
	}
	url := params.TestURL
	if url == "" {
		url = currentTestURL()
	}
	delay, err := previous.URLTest(ctx, url, anyDelayTestStatus)
	value := int32(max(delay, 1))
	if err != nil {
		value = delayValue(0, ctx.Err() != nil)
	}
	return &Delay{Name: "", Url: url, Value: value}, nil
}
