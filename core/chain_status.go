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
	CoreEpoch        uint64 `json:"core-epoch"`
	RouteVersion     uint64 `json:"route-version"`
	Running          bool   `json:"running"`
	Selected         bool   `json:"selected"`
	Proxy            string `json:"proxy"`
	ProxyType        string `json:"proxy-type"`
	Target           string `json:"target"`
	Entry            string `json:"entry"`
	EntryConnections int    `json:"entry-connections"`
	ExitConnections  int    `json:"exit-connections"`
	Upload           int64  `json:"upload"`
	Download         int64  `json:"download"`
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
	if entry := lookupProxy(exit.ProxyInfo().DialerProxy); entry != nil {
		result.Entry = entry.Name()
	}
	statistic.DefaultManager.Range(func(tracker statistic.Tracker) bool {
		info := tracker.Info()
		if result.Entry != "" && info.Metadata.Type == constant.INNER && slices.Contains(info.Chain, result.Entry) {
			result.EntryConnections++
			result.Upload += info.UploadTotal.Load()
			result.Download += info.DownloadTotal.Load()
		}
		if slices.Contains(info.Chain, result.Proxy) {
			result.ExitConnections++
			if result.Entry == "" {
				result.Upload += info.UploadTotal.Load()
				result.Download += info.DownloadTotal.Load()
			}
		}
		return true
	})
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
