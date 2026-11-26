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
	exit := lookupProxy(params.Proxy)
	if exit == nil {
		return result
	}
	entry := lookupProxy(exit.ProxyInfo().DialerProxy)
	if entry == nil {
		return result
	}
	result.Entry = entry.Name()
	target := params.Target
	switch tunnel.Mode() {
	case tunnel.Global:
		target = "GLOBAL"
	case tunnel.Direct:
		target = "DIRECT"
	}
	result.Selected = exitThrough(lookupProxy(target), &constant.Metadata{NetWork: constant.TCP}) == exitName(exit)
	statistic.DefaultManager.Range(func(tracker statistic.Tracker) bool {
		info := tracker.Info()
		if info.Metadata.Type == constant.INNER && slices.Contains(info.Chain, result.Entry) {
			result.EntryConnections++
			result.Upload += info.UploadTotal.Load()
			result.Download += info.DownloadTotal.Load()
		}
		if slices.Contains(info.Chain, params.Proxy) {
			result.ExitConnections++
		}
		return true
	})
	return result
}
