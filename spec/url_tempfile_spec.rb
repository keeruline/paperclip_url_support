require 'spec_helper'

describe URLTempfile do
  let(:path_end)     { 'file.jpg' }
  let(:url_scheme)   { 'http' }
  let(:url_base)     { "example.com/some/path"}
  let(:url)          { "#{url_scheme}://#{url_base}/#{path_end}" }
  let(:body)         { 'the-file-body' }
  let(:content_type) { 'image/jpeg' }
  subject            { URLTempfile.new(url) }

  def stub_http_request(status, url)
    stub_request(:get, url).to_return(
      :body    => body,
      :status  => status,
      :headers => { 'Content-Type' => content_type }
    )
  end

  def stub_http_redirect(status, from, to)
    from_url = "#{from}://#{url_base}"
    to_url = "#{to}://#{url_base}/#{path_end}"

    stub_request(:get, from_url).to_return(
      :status  => status,
      :headers => { 'location' => to_url }
    )
    stub_http_request(200, to_url)
  end

  context "when the request has a 200 status code" do
    before(:each) { stub_http_request(200, url) }

    its(:content_type)      { should == content_type }
    its(:original_filename) { should == path_end }

    it 'has the correct content' do
      subject.rewind
      subject.read.should == body
    end
  end

  [
    {:status => 301, :from => 'http',  :to => 'http'},
    {:status => 302, :from => 'http',  :to => 'https'},
    {:status => 303, :from => 'https', :to => 'http'},
    {:status => 304, :from => 'https', :to => 'https'}
  ].each do |redirect|
    context "when the request has a 30x status code" do
      subject { URLTempfile.new("#{redirect[:from]}://#{url_base}") }
      before(:each) { stub_http_redirect(redirect[:status], redirect[:from], redirect[:to]) }

      its(:content_type)      { should == content_type }
      its(:original_filename) { should == path_end }

      it 'has the correct content' do
        subject.rewind
        subject.read.should == body
      end
    end
  end

  [404, 500].each do |status|
    context "when the request has a #{status} status code" do
      before(:each) { stub_http_request(status, url) }

      it 'raises an error' do
        expect { subject }.to raise_error(URLTempfile::UnsuccessfulHTTPResponse)
      end
    end
  end
end
