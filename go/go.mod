module github.com/inverse-inc/packetfence/go

go 1.13

require (
	github.com/Sereal/Sereal v0.0.0-20161214074320-36f2c9f6f409
	github.com/Shopify/sarama v1.24.0 // indirect
	github.com/apache/thrift v0.0.0-20180124195629-23dde8c446bb // indirect
	github.com/beorn7/perks v1.0.1 // indirect
	github.com/captncraig/cors v0.0.0-20170507232344-153f484dcf3d
	github.com/cevaris/ordered_map v0.0.0-20171019141434-01ce2b16ad4f
	github.com/coreos/etcd v3.3.15+incompatible
	github.com/coreos/go-semver v0.3.0 // indirect
	github.com/coreos/go-systemd v0.0.0-20190719114852-fd7a80b32e1f
	github.com/davecgh/go-spew v1.1.1
	github.com/diegoguarnieri/go-conntrack v0.0.0-20161208180411-9abb0707ff31
	github.com/dnstap/golang-dnstap v0.0.0-20170829151710-2cf77a2b5e11
	github.com/farsightsec/golang-framestream v0.0.0-20180124174429-c06a5734334d
	github.com/fdurand/arp v0.0.0-20180807174648-27b38d3af1be
	github.com/fdurand/go-cache v0.0.0-20180104143916-cf0198ac7d92
	github.com/flynn/go-shlex v0.0.0-20150515145356-3f9db97f8568 // indirect
	github.com/gdey/jsonpath v0.0.0-20151203210429-124c978a1ffc
	github.com/go-errors/errors v0.0.0-20180813162953-d98b870cc4e0
	github.com/go-logfmt/logfmt v0.4.0 // indirect
	github.com/go-redis/redis v0.0.0-20190325112110-a679e614427a
	github.com/go-sql-driver/mysql v0.0.0-20190330032241-c0f6b444ad8f
	github.com/go-stack/stack v1.8.0 // indirect
	github.com/gogo/protobuf v1.3.1 // indirect
	github.com/goji/httpauth v0.0.0-20160601135302-2da839ab0f4d
	github.com/golang/groupcache v0.0.0-20191002201903-404acd9df4cc // indirect
	github.com/golang/protobuf v1.3.2
	github.com/google/go-cmp v0.3.0
	github.com/google/uuid v1.1.1
	github.com/gorilla/context v1.1.1 // indirect
	github.com/gorilla/mux v0.0.0-20180120075819-c0091a029979
	github.com/gorilla/rpc v0.0.0-20160927134711-22c016f3df3f
	github.com/grpc-ecosystem/grpc-gateway v1.11.3 // indirect
	github.com/grpc-ecosystem/grpc-opentracing v0.0.0-20171214222146-0e7658f8ee99
	github.com/hpcloud/tail v1.0.0
	github.com/inconshreveable/log15 v0.0.0-20171019012758-0decfc6c20d9
	github.com/inverse-inc/go-ipset v0.0.0-20190925174109-4d5749cc4aa6
	github.com/json-iterator/go v1.1.7 // indirect
	github.com/julienschmidt/httprouter v0.0.0-20171027133709-e1b9828bc9e5
	github.com/kr/pretty v0.1.0
	github.com/krolaw/dhcp4 v0.0.0-20171222085133-4abfceffa76a
	github.com/mattn/go-colorable v0.1.4 // indirect
	github.com/mattn/go-isatty v0.0.10 // indirect
	github.com/matttproud/golang_protobuf_extensions v0.0.0-20160424113007-c12348ce28de
	github.com/mdlayher/ethernet v0.0.0-20170707213343-e72cf8343052
	github.com/mdlayher/raw v0.0.0-20171214195253-9df8b4265df2
	github.com/mediocregopher/radix.v2 v0.0.0-20180603022615-94360be26253
	github.com/mholt/caddy v0.9.5
	github.com/miekg/dns v1.1.3
	github.com/modern-go/reflect2 v1.0.1 // indirect
	github.com/nu7hatch/gouuid v0.0.0-20131221200532-179d4d0c4d8d
	github.com/opentracing-contrib/go-observer v0.0.0-20170622124052-a52f23424492 // indirect
	github.com/opentracing/opentracing-go v1.1.0
	github.com/openzipkin/zipkin-go-opentracing v0.0.0-20180123190626-6bb822a7f15f
	github.com/patrickmn/go-cache v0.0.0-20170722040110-a3647f8e31d7
	github.com/pierrec/lz4 v2.3.0+incompatible // indirect
	github.com/prometheus/client_golang v0.0.0-20180120141031-06bc6e01f4ba
	github.com/prometheus/client_model v0.0.0-20171117100541-99fa1f4be8e5
	github.com/prometheus/common v0.0.0-20180110214958-89604d197083
	github.com/prometheus/procfs v0.0.5 // indirect
	github.com/simon/go-netadv v0.0.0-20170602081515-fe67988531c7
	go.etcd.io/bbolt v1.3.3 // indirect
	golang.org/x/crypto v0.0.0-20190404164418-38d8ce5564a5
	golang.org/x/net v0.0.0-20190404232315-eb5bcb51f2a3
	google.golang.org/grpc v1.19.0
	gopkg.in/alexcesaro/statsd.v2 v2.0.0-20160320182110-7fea3f0d2fab
	gopkg.in/asn1-ber.v1 v1.0.0-20181015200546-f715ec2f112d // indirect
	gopkg.in/fsnotify.v1 v1.4.7 // indirect
	gopkg.in/ldap.v2 v2.0.0-20171123045618-bb7a9ca6e4fb
	gopkg.in/tomb.v1 v1.0.0-20141024135613-dd632973f1e7 // indirect
	layeh.com/radius v0.0.0-20180123164351-38e2cda15058
)

replace github.com/inverse-inc/packetfence => ../

replace github.com/inverse-inc/packetfence/go => ./

replace github.com/inverse-inc/packetfence/go/caddy/caddy => ./go/caddy/caddy
