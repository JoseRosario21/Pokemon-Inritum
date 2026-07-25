stdlib_path = File.join(Dir.pwd, 'stdlib')
$LOAD_PATH.unshift(stdlib_path) unless $LOAD_PATH.include?(stdlib_path)
stdlib_arch_path = File.join(stdlib_path, 'x64-mingw32')
$LOAD_PATH.unshift(stdlib_arch_path) unless $LOAD_PATH.include?(stdlib_arch_path)
gems_path = File.join(Dir.pwd, 'gems')
$LOAD_PATH.unshift(gems_path) unless $LOAD_PATH.include?(gems_path)

require 'rbconfig'
require 'openssl'
require 'net/http'

module EngineNetworking
  # This build's OpenSSL doesn't reliably resolve SSL_CERT_FILE/default cert
  # paths on Windows, so the cert store is built explicitly per-request instead.
  def self.cert_store
    @cert_store ||= begin
      store = OpenSSL::X509::Store.new
      store.add_file(File.join(Dir.pwd, 'cacert.pem'))
      store
    end
  end

  # GitHub release assets (and gist raw URLs, sometimes) respond with a 302 to
  # a CDN host rather than the content directly, so redirects have to be
  # followed manually here.
  def self.https_get(url, timeout: 10, redirect_limit: 5)
    raise "Too many redirects for #{url}" if redirect_limit < 0
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.cert_store = self.cert_store if http.use_ssl?
    http.open_timeout = timeout
    http.read_timeout = timeout
    response = http.get(uri.request_uri)
    case response
    when Net::HTTPRedirection
      return self.https_get(response['location'], timeout: timeout, redirect_limit: redirect_limit - 1)
    when Net::HTTPSuccess
      return response.body
    else
      raise "HTTP #{response.code} for #{url}"
    end
  end
end
