package core

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/common/convert"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	"go.yaml.in/yaml/v3"
)

type ProviderSnapshotParams struct {
	Definition map[string]any `json:"definition"`
	Content    string         `json:"content"`
	Refresh    bool           `json:"refresh"`
}

func handleProviderSnapshot(params ProviderSnapshotParams) ([]map[string]any, error) {
	var persist func() error
	if params.Content == "" && params.Definition["type"] != "inline" {
		path, _ := params.Definition["path"].(string)
		if !constant.Path.IsSafePath(path) {
			return nil, constant.Path.ErrNotSafePath(path)
		}
		buf, err := os.ReadFile(path)
		if params.Refresh && params.Definition["type"] == "http" {
			cacheRoot := filepath.Join(constant.Path.HomeDir(), "profiles", "providers")
			relative, pathErr := filepath.Rel(cacheRoot, filepath.Clean(path))
			if pathErr != nil || relative == "." || relative == ".." || strings.HasPrefix(relative, ".."+string(filepath.Separator)) {
				return nil, fmt.Errorf("provider snapshot cache must be inside profiles/providers")
			}
			definition := map[string]any{}
			for key, value := range params.Definition {
				definition[key] = value
			}
			definition["health-check"] = map[string]any{"enable": false}
			definition["interval"] = 0
			delete(definition, "payload")
			pd, parseErr := provider.ParseProxyProvider("aggregate-download", definition, tunnel.Tunnel)
			if parseErr != nil {
				return nil, parseErr
			}
			set := pd.(*provider.ProxySetProvider)
			defer set.Close()
			buf, _, err = set.Vehicle().Read(context.Background(), utils.HashType{})
			persist = func() error { return set.Vehicle().Write(buf) }
		}
		if err != nil {
			return nil, err
		}
		params.Content = string(buf)
	}
	source := provider.ProxySchema{}
	if params.Content != "" {
		key, _ := params.Definition["age-secret-key"].(string)
		buf, err := age.DecryptBytes([]byte(params.Content), key)
		if err != nil {
			return nil, err
		}
		if err := yaml.Unmarshal(buf, &source); err != nil || source.Proxies == nil {
			proxies, err := convert.ConvertsV2Ray(buf)
			if err != nil {
				return nil, err
			}
			source.Proxies = proxies
		}
	} else {
		buf, err := json.Marshal(params.Definition["payload"])
		if err != nil {
			return nil, err
		}
		if err := json.Unmarshal(buf, &source.Proxies); err != nil {
			return nil, err
		}
	}
	result := make([]map[string]any, 0, len(source.Proxies))
	seen := map[string]bool{}
	for _, item := range source.Proxies {
		name, _ := item["name"].(string)
		if seen[name] {
			continue
		}
		seen[name] = true
		definition := map[string]any{}
		for key, value := range params.Definition {
			definition[key] = value
		}
		definition["type"] = "inline"
		definition["payload"] = []map[string]any{item}
		definition["health-check"] = map[string]any{"enable": false}
		delete(definition, "age-secret-key")
		overrides := map[string]any{}
		if existing, ok := definition["override"].(map[string]any); ok {
			for key, value := range existing {
				overrides[key] = value
			}
		}
		var expressions []any
		if encoded, err := json.Marshal(overrides["override-expr"]); err == nil {
			_ = json.Unmarshal(encoded, &expressions)
		}
		suffix := "@aggregate-snapshot-" + rand.Text()
		literal, _ := json.Marshal(suffix)
		overrides["override-expr"] = append(expressions, ".name += "+string(literal))
		definition["override"] = overrides
		buf, err := json.Marshal(definition)
		if err != nil {
			return nil, err
		}
		var parsing map[string]any
		if err := json.Unmarshal(buf, &parsing); err != nil {
			return nil, err
		}
		// Singleton payloads keep the core's filter/override semantics linear.
		pd, err := provider.ParseProxyProvider("aggregate-snapshot", parsing, tunnel.Tunnel)
		if err != nil {
			if strings.Contains(err.Error(), "doesn't match any proxy") || err.Error() == "file doesn't have any proxy" {
				continue
			}
			return nil, fmt.Errorf("%s: %w", name, err)
		}
		proxies := pd.Proxies()
		var mapping map[string]any
		if len(proxies) > 0 {
			mapping, err = provider.ProxyMapping(pd, definition, proxies[0].Name())
		}
		for _, proxy := range proxies {
			proxy.Close()
		}
		if closer, ok := pd.(interface{ Close() error }); ok {
			closer.Close()
		}
		if err != nil {
			return nil, err
		}
		if mapping != nil {
			if actual, ok := mapping["name"].(string); ok {
				mapping["name"] = strings.TrimSuffix(actual, suffix)
			}
			result = append(result, mapping)
		}
	}
	if persist != nil {
		if err := persist(); err != nil {
			return nil, err
		}
	}
	return result, nil
}
