---

# -----------------------------------------------------------------------------
# File: cert-vault-sync/templates/_helpers.tpl
# -----------------------------------------------------------------------------

{{/*
Reverse domain string into Vault folder path (e.g. summer.ctlabs.internal ->
internal/ctlabs/summer). A leading "*." wildcard is stripped first, so a
wildcard cert's path is its parent domain's path, not a literal "*" segment
(e.g. *.g-tr2.oanda.com -> com/oanda/g-tr2).
*/}}
{{- define "cert-vault-sync.reverseDomain" -}}
{{- $domain := trimPrefix "*." . -}}
{{- $parts := splitList "." $domain -}}
{{- $reversed := reverse $parts -}}
{{- join "/" $reversed -}}
{{- end -}}

{{/*
Generate a standardized store name from a Vault mount path (e.g. secrets/dev -> vault-backend-secrets-dev)
*/}}
{{- define "cert-vault-sync.storeName" -}}
{{- $slug := . | replace "/" "-" | replace "_" "-" | lower -}}
{{- printf "vault-backend-%s" $slug -}}
{{- end -}}

{{/*
Format domain to valid RFC 1123 Kubernetes name. A leading "*." wildcard
("*" is not a legal name character, and unquoted would parse as a YAML
alias in the rendered manifest) is stripped, not replaced - so a wildcard
cn produces the exact same object name as its bare domain, same as
reverseDomain above (e.g. *.g-tr2.oanda.com -> g-tr2-oanda-com, same as cn:
g-tr2.oanda.com would). This also means a wildcard-in-cn entry and a
plain-domain entry can never coexist without colliding on the same object -
intentional, since they'd be the same certificate either way.
*/}}
{{- define "cert-vault-sync.slug" -}}
{{- trimPrefix "*." . | replace "." "-" | replace "_" "-" | lower -}}
{{- end -}}

{{/*
Effective renewBeforePercentage for a cert: base percentage plus a 0..spread
offset assigned by the cert's POSITION in its environment's certs list -
first cert keeps the base, last cert gets base+spread, evenly spaced between
(integer division, so with small spread/N some adjacent offsets repeat by at
most one step). Positional on purpose instead of a cn-hash: hashing similar
structured names (svc-001..., app1.tr2...) clusters - only part of the
buckets get used and some certs pile into one - while list position is even
by construction no matter what the names look like. Stable across re-renders
while list order and count are unchanged; adding/removing certs renumbers
the offsets but they stay perfectly even. Spread 0 or a single-cert list =
offset 0 (cert pinned to the base). Call with dict: cert=<merged
defaults+cert dict>, index=<range index>, count=<len of certs list>.
*/}}
{{- define "cert-vault-sync.renewBeforePercentage" -}}
{{- $base := int .cert.renewBeforePercentage -}}
{{- $spread := int (default 0 .cert.renewBeforePercentageSpread) -}}
{{- $offset := 0 -}}
{{- if and (gt $spread 0) (gt (int .count) 1) -}}
{{- $offset = div (mul (int .index) $spread) (sub (int .count) 1) -}}
{{- end -}}
{{- add $base $offset -}}
{{- end -}}
