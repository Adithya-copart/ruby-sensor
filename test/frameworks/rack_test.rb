require 'test_helper'
require 'rack/test'
require 'rack/lobster'
require "instana/rack"

class RackTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use Instana::Rack
      map "/mrlobster" do
        run Rack::Lobster.new
      end
    }
  end

  def test_basic_get
    clear_all!
    ::Instana.config[:collect_backtraces] = true

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count

    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "GET", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert_equal 'example.org', first_span[:data][:http][:host]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]

    # Backtrace fingerprint validation
    assert first_span.key?(:stack)
    assert_equal 2, first_span[:stack].count
    refute_nil first_span[:stack].first[:c].match(/instana\/instrumentation\/rack.rb/)

    # Restore to default
    ::Instana.config[:collect_backtraces] = false
  end

  def test_basic_get_with_custom_service_name
    ENV['INSTANA_SERVICE_NAME'] = 'WalterBishop'

    clear_all!
    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count

    first_span = spans.first
    assert_equal 'WalterBishop', first_span[:data][:service]

    ENV.delete('INSTANA_SERVICE_NAME')
  end

  def test_basic_post
    clear_all!
    post '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "POST", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
  end

  def test_basic_put
    clear_all!
    put '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "PUT", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
  end

  def test_context_continuation
    clear_all!
    header 'X-INSTANA-T', Instana::Util.id_to_header(1234)
    header 'X-INSTANA-S', Instana::Util.id_to_header(4321)

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "GET", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]

    # Context validation
    # The first span should have the passed in trace ID
    # and specify the passed in span ID as it's parent.
    assert_equal 1234, first_span[:t]
    assert_equal 4321, first_span[:p]
  end

  def test_instana_response_headers
    clear_all!
    get '/mrlobster'
    assert last_response.ok?

    refute_nil last_response.headers.key?("X-Instana-T")
    refute_nil last_response.headers.key?("X-Instana-S")
  end

  def test_that_url_params_not_logged
    clear_all!
    get '/mrlobster?blah=2&wilma=1&betty=2;fred=3'

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    refute_nil spans.first.key?(:data)
    refute_nil spans.first[:data].key?(:http)
    refute_nil spans.first[:data][:http].key?(:url)
    assert_equal '/mrlobster', spans.first[:data][:http][:url]

    assert last_response.ok?
  end

  def test_custom_headers_capture
    clear_all!
    ::Instana.config[:collect_backtraces] = true
    ::Instana.agent.extra_headers = %w(X-Capture-This X-Capture-That)

    get '/mrlobster', {}, { "HTTP_X_CAPTURE_THIS" => "ThereYouGo" }
    assert last_response.ok?
    assert_equal "ThereYouGo", last_request.env["HTTP_X_CAPTURE_THIS"]

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    first_span = spans.first

    assert first_span[:data][:http].key?(:header)
    assert first_span[:data][:http][:header].key?(:"X-Capture-This")
    assert !first_span[:data][:http][:header].key?(:"X-Capture-That")
    assert_equal "ThereYouGo", first_span[:data][:http][:header][:"X-Capture-This"]

    # Backtrace fingerprint validation
    assert first_span.key?(:stack)
    assert_equal 2, first_span[:stack].count
    refute_nil first_span[:stack].first[:c].match(/instana\/instrumentation\/rack.rb/)

    # Restore to default
    ::Instana.config[:collect_backtraces] = false
    ::Instana.agent.extra_headers = nil
  end
end
