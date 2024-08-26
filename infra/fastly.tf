resource "fastly_service_vcl" "test_python_org" {
  name               = "test.python.org"
  default_ttl        = 3600
  http3              = false
  stale_if_error     = false
  stale_if_error_ttl = 43200
  activate           = true
#
#   domain {
#     name = "test.python.org"
#   }

  domain {
    name    = var.USER_VCL_SERVICE_DOMAIN_NAME
    comment = "NGWAF testing domain"
  }

  backend {
    name                  = "cabotage"
    address               = "test-pythondotorg.ingress.us-east-2.psfhosted.computer"
    port                  = 443
    shield                = "iad-va-us"
    auto_loadbalance      = false
    ssl_check_cert        = true
    ssl_cert_hostname     = "test-pythondotorg.ingress.us-east-2.psfhosted.computer"
    ssl_sni_hostname      = "test-pythondotorg.ingress.us-east-2.psfhosted.computer"
    weight                = 100
    max_conn              = 200
    connect_timeout       = 1000
    first_byte_timeout    = 30000
    between_bytes_timeout = 10000
  }

  backend {
    name                  = "loadbalancer"
    address               = "lb.nyc1.psf.io"
    shield                = "iad-va-us"
    healthcheck           = "HAProxy Status"
    auto_loadbalance      = false
    ssl_check_cert        = true
    ssl_cert_hostname     = "lb.psf.io"
    ssl_sni_hostname      = "lb.psf.io"
    ssl_ca_cert           = "" # TODO(@ee)
    weight                = 100
    max_conn              = 200
    connect_timeout       = 1000
    first_byte_timeout    = 15000
    between_bytes_timeout = 10000
  }

  backend {
    address           = var.USER_VCL_SERVICE_BACKEND_HOSTNAME
    name              = "ngwaf_backend"
    port              = 443
    use_ssl           = true
    ssl_cert_hostname = var.USER_VCL_SERVICE_BACKEND_HOSTNAME
    ssl_sni_hostname  = var.USER_VCL_SERVICE_BACKEND_HOSTNAME
    override_host     = var.USER_VCL_SERVICE_BACKEND_HOSTNAME
  }

  acl {
    name          = "Generated_by_IP_block_list"
    force_destroy = false
  }

  cache_setting {
    action          = "pass"
    cache_condition = "Force Pass No-Cache No-Store"
    name            = "Pass No-Cache No-Store"
    stale_ttl       = 0
    ttl             = 0
  }

  condition {
    name      = "Force Pass No-Cache No-Store"
    priority  = 10
    statement = "beresp.http.Cache-Control ~ \"(no-cache|no-store)\""
    type      = "CACHE"
  }
  condition {
    name      = "Generated by IP block list"
    priority  = 0
    statement = "client.ip ~ Generated_by_IP_block_list"
    type      = "REQUEST"
  }
  condition {
    name      = "HSTS w/ subdomains"
    priority  = 10
    statement = "req.http.host == \"test.python.org\""
    type      = "RESPONSE"
  }
  condition {
    name      = "HSTS w/o subdomain"
    priority  = 10
    statement = "req.http.host == \"test.python.org\""
    type      = "RESPONSE"
  }
  condition {
    name      = "Homepage"
    priority  = 10
    statement = "req.url.path ~ \"^/$\""
    type      = "REQUEST"
  }
  condition {
    name      = "Is Download"
    priority  = 10
    statement = "req.url ~ \"^/ftp/\""
    type      = "REQUEST"
  }
  condition {
    name      = "Is Not Download"
    priority  = 5
    statement = "req.url !~ \"^/ftp/\""
    type      = "REQUEST"
  }
  condition {
    name      = "Uncacheable URLs"
    priority  = 10
    statement = "req.url ~ \"^/(api|admin)/\""
    type      = "REQUEST"
  }
  condition {
    name      = "apex redirect"
    priority  = 10
    statement = "req.http.Host == \"test.python.org\""
    type      = "RESPONSE"
  }
  condition {
    name      = "apex"
    priority  = 1
    statement = "req.http.host == \"test.python.org\""
    type      = "REQUEST"
  }

  gzip {
    name = "Default rules"
    content_types = [
      "application/javascript",
      "text/css",
      "application/javascript",
      "text/javascript",
      "application/json",
      "application/vnd.ms-fontobject",
      "application/x-font-opentype",
      "application/x-font-truetype",
      "application/x-font-ttf",
      "application/xml",
      "font/eot",
      "font/opentype",
      "font/otf",
      "image/svg+xml",
      "image/vnd.microsoft.icon",
      "text/plain",
      "text/xml",
    ]
  }

  header {
    action            = "delete"
    destination       = "http.Cookie"
    name              = "Remove cookies"
    priority          = 10
    request_condition = "Is Download"
    type              = "request"
  }
  header {
    action            = "set"
    destination       = "backend"
    name              = "Is Download Director"
    priority          = 10
    request_condition = "Is Download"
    source            = "F_lb_nyc1_psf_io"
    type              = "request"
  }
  header {
    action            = "set"
    destination       = "backend"
    name              = "Is Not Download Backend"
    priority          = 10
    request_condition = "Is Not Download"
    source            = "F_cabotage"
    type              = "request"
  }
  header {
    action      = "set"
    destination = "http.Fastly-Token"
    name        = "Fastly Token"
    priority    = 10
    source      = var.FASTLY_HEADER_TOKEN
    type        = "request"
  }
  header {
    action             = "set"
    destination        = "http.Location"
    name               = "www redirect"
    priority           = 10
    response_condition = "apex redirect"
    source             = "\"https://test.python.org\" + req.url"
    type               = "response"
  }
  header {
    action             = "set"
    destination        = "http.Strict-Transport-Security"
    name               = "HSTS w/ subdomains"
    priority           = 10
    response_condition = "HSTS w/ subdomains"
    source             = "\"max-age=63072000; includeSubDomains; preload\""
    type               = "response"
  }
  header {
    action             = "set"
    destination        = "http.Strict-Transport-Security"
    name               = "HSTS w/o subdomains"
    priority           = 10
    response_condition = "HSTS w/o subdomain"
    source             = "\"max-age=315360000; preload\""
    type               = "response"
  }
  header {
    action            = "set"
    destination       = "url"
    name              = "Chop off query string"
    priority          = 10
    request_condition = "Is Download"
    source            = "regsub(req.url, \"\\?.*$\", \"\")"
    type              = "request"
  }
  header {
    action            = "set"
    destination       = "url"
    name              = "Strip Query Strings"
    priority          = 10
    request_condition = "Homepage"
    source            = "req.url.path"
    type              = "request"
  }

  healthcheck {
    check_interval    = 15000
    expected_response = 200
    host              = "test.python.org"
    http_version      = "1.1"
    initial           = 4
    method            = "HEAD"
    name              = "HAProxy Status"
    path              = "/_haproxy_status"
    threshold         = 3
    timeout           = 5000
    window            = 5
  }

  logging_datadog {
    name   = "ratelimit-debug"
    token  = var.DATADOG_API_KEY
    region = "US"
  }

  logging_s3 {
    name              = "psf-fastly-logs"
    bucket_name       = "psf-fastly-logs-eu-west-1"
    domain            = "s3-eu-west-1.amazonaws.com"
    path              = "/www-python-org/%Y/%m/%d/"
    period            = 3600
    gzip_level        = 9
    format            = "%%h \"%%{now}V\" %%l \"%%{req.request}V %%{req.url}V\" %%{req.proto}V %%>s %%{resp.http.Content-Length}V %%{resp.http.age}V \"%%{resp.http.x-cache}V\" \"%%{resp.http.x-cache-hits}V\" \"%%{req.http.content-type}V\" \"%%{req.http.accept-language}V\" \"%%{cstr_escape(req.http.user-agent)}V\""
    timestamp_format  = "%Y-%m-%dT%H:%M:%S.000"
    redundancy        = "standard"
    format_version    = 2
    message_type      = "classic"
    s3_access_key     = var.S3_ACCESS_KEY
    s3_secret_key     = var.S3_SECRET_KEY
  }

  logging_syslog {
    name    = "syslog"
    address = "cdn-logs.nyc1.psf.io"
    port    = 514
    format  = "%%h \"%%{now}V\" %%l \"%%{req.request}V %%{req.url}V\" %%{req.proto}V %%>s %%{resp.http.Content-Length}V %%{resp.http.age}V \"%%{resp.http.x-cache}V\" \"%%{resp.http.x-cache-hits}V\" \"%%{req.http.content-type}V\" \"%%{req.http.accept-language}V\" \"%%{cstr_escape(req.http.user-agent)}V\""
  }

  product_enablement {
    bot_management     = true
    brotli_compression = false
    domain_inspector   = true
    image_optimizer    = false
    origin_inspector   = true
    websockets         = false
  }

  rate_limiter {
    action               = "log_only"
    client_key           = "client.ip"
    feature_revision     = 1
    http_methods         = "GET,PUT,TRACE,POST,HEAD,DELETE,PATCH,OPTIONS"
    logger_type          = "datadog"
    name                 = "test.python.org backends"
    penalty_box_duration = 2
    rps_limit            = 10
    window_size          = 10

    response {
      content      = <<-EOT
                <html>
                        <head>
                                <title>Too Many Requests</title>
                        </head>
                        <body>
                                <p>Too Many Requests</p>
                        </body>
                </html>
            EOT
      content_type = "text/html"
      status       = 429
    }
  }

  request_setting {
    action           = null
    bypass_busy_wait = false
    force_ssl        = true
    max_stale_age    = 86400
    name             = "Default cache policy"
    xff              = "append"
  }
  request_setting {
    action            = "pass"
    bypass_busy_wait  = false
    force_ssl         = false
    max_stale_age     = 60
    name              = "Force Pass"
    request_condition = "Uncacheable URLs"
    xff               = "append"
  }

  response_object {
    name              = "www redirect"
    request_condition = "apex"
    response          = "Moved Permanently"
    status            = 301
  }
  response_object {
    content_type      = "text/html"
    name              = "Generated by IP block list"
    request_condition = "Generated by IP block list"
    response          = "Forbidden"
    status            = 403
  }

  # NGWAF Dynamic Snippets
  dynamicsnippet {
    name     = "ngwaf_config_init"
    type     = "init"
    priority = 0
  }

  dynamicsnippet {
    name     = "ngwaf_config_miss"
    type     = "miss"
    priority = 9000
  }

  dynamicsnippet {
    name     = "ngwaf_config_pass"
    type     = "pass"
    priority = 9000
  }

  dynamicsnippet {
    name     = "ngwaf_config_deliver"
    type     = "deliver"
    priority = 9000
  }

  dictionary {
    name = var.Edge_Security_dictionary
  }

  lifecycle {
    ignore_changes = [product_enablement]
  }

  force_destroy = true
}

# Fastly Service Dictionary Items
resource "fastly_service_dictionary_items" "edge_security_dictionary_items" {
  for_each = {
    for d in fastly_service_vcl.test_python_org.dictionary : d.name => d if d.name == var.Edge_Security_dictionary
  }
  service_id    = fastly_service_vcl.test_python_org.id
  dictionary_id = each.value.dictionary_id
  items = {
    Enabled : "100"
  }
}

# Fastly Service Dynamic Snippet Contents
resource "fastly_service_dynamic_snippet_content" "ngwaf_config_init" {
  for_each = {
    for d in fastly_service_vcl.test_python_org.dynamicsnippet : d.name => d if d.name == "ngwaf_config_init"
  }
  service_id      = fastly_service_vcl.test_python_org.id
  snippet_id      = each.value.snippet_id
  content         = "### Fastly managed ngwaf_config_init"
  manage_snippets = false
}

resource "fastly_service_dynamic_snippet_content" "ngwaf_config_miss" {
  for_each = {
    for d in fastly_service_vcl.test_python_org.dynamicsnippet : d.name => d if d.name == "ngwaf_config_miss"
  }
  service_id      = fastly_service_vcl.test_python_org.id
  snippet_id      = each.value.snippet_id
  content         = "### Fastly managed ngwaf_config_miss"
  manage_snippets = false
}

resource "fastly_service_dynamic_snippet_content" "ngwaf_config_pass" {
  for_each = {
    for d in fastly_service_vcl.test_python_org.dynamicsnippet : d.name => d if d.name == "ngwaf_config_pass"
  }
  service_id      = fastly_service_vcl.test_python_org.id
  snippet_id      = each.value.snippet_id
  content         = "### Fastly managed ngwaf_config_pass"
  manage_snippets = false
}

resource "fastly_service_dynamic_snippet_content" "ngwaf_config_deliver" {
  for_each = {
    for d in fastly_service_vcl.test_python_org.dynamicsnippet : d.name => d if d.name == "ngwaf_config_deliver"
  }
  service_id      = fastly_service_vcl.test_python_org.id
  snippet_id      = each.value.snippet_id
  content         = "### Fastly managed ngwaf_config_deliver"
  manage_snippets = false
}
