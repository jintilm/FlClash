package core

import (
	"slices"

	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

type ChainStatusParams struct {
	Proxy  string `json:"proxy"`
	Target string `json:"target"`
}

type ChainStatus struct {
	CoreEpoch        uint64           `json:"core-epoch"`
	RouteVersion     uint64           `json:"route-version"`
	Running          bool             `json:"running"`
	Selected         bool             `json:"selected"`
	Proxy            string           `json:"proxy"`
	ProxyType        string           `json:"proxy-type"`
	Target           string           `json:"target"`
	Entry            string           `json:"entry"`
	EntryConnections int              `json:"entry-connections"`
	ExitConnections  int              `json:"exit-connections"`
	Upload           int64            `json:"upload"`
	Download         int64            `json:"download"`
	Hops             []ChainHopStatus `json:"hops"`
}

type ChainHopStatus struct {
	Name        string `json:"name"`
	Connections int    `json:"connections"`
	Upload      int64  `json:"upload"`
	Download    int64  `json:"download"`
}

func handleChainStatus(params ChainStatusParams) ChainStatus {
	refreshRoute()
	route := routeState()
	result := ChainStatus{CoreEpoch: route.CoreEpoch, RouteVersion: route.RouteVersion, Running: route.Running}
	target := params.Target
	switch tunnel.Mode() {
	case tunnel.Global:
		target = "GLOBAL"
	case tunnel.Direct:
		target = "DIRECT"
	}
	result.Target = target
	selected := statusOutbound(lookupProxy(target))
	exit := lookupProxy(params.Proxy)
	if params.Proxy == "" {
		exit = selected
	}
	if exit == nil {
		return result
	}
	result.Proxy, result.ProxyType = exit.Name(), exit.Type().String()
	result.Selected = selected != nil && exitName(selected) == exitName(exit)
	seen := map[string]bool{}
	for hop := exit; hop != nil && !seen[hop.Name()]; hop = statusOutbound(lookupProxy(hop.ProxyInfo().DialerProxy)) {
		seen[hop.Name()] = true
		result.Hops = append(result.Hops, ChainHopStatus{Name: hop.Name()})
	}
	slices.Reverse(result.Hops)
	if len(result.Hops) > 1 {
		result.Entry = result.Hops[0].Name
	}
	positions := make(map[string]int, len(result.Hops))
	for index, hop := range result.Hops {
		positions[hop.Name] = index
	}
	statistic.DefaultManager.Range(func(tracker statistic.Tracker) bool {
		info := tracker.Info()
		for _, name := range info.Chain {
			if index, ok := positions[name]; ok && (index == len(result.Hops)-1 || info.Metadata.Type == constant.INNER) {
				hop := &result.Hops[index]
				hop.Connections++
				hop.Upload += info.UploadTotal.Load()
				hop.Download += info.DownloadTotal.Load()
			}
		}
		return true
	})
	result.ExitConnections = result.Hops[len(result.Hops)-1].Connections
	if result.Entry != "" {
		result.EntryConnections = result.Hops[0].Connections
	}
	result.Upload, result.Download = result.Hops[0].Upload, result.Hops[0].Download
	return result
}

func statusOutbound(proxy constant.Proxy) constant.Proxy {
	visited := map[string]bool{}
	for proxy != nil {
		if visited[proxy.Name()] {
			return nil
		}
		visited[proxy.Name()] = true
		if proxy.Type() == constant.LoadBalance {
			return proxy
		}
		next := proxy.Unwrap(&constant.Metadata{NetWork: constant.TCP}, false)
		if next == nil {
			return proxy
		}
		proxy = next
	}
	return nil
}
