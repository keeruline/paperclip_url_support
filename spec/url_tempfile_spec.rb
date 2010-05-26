require 'spec_helper'

describe URLTempfile do
  let(:path_end)     { 'file.jpg' }
  let(:url)          { "http://example.com/some/path/#{path_end}" }
  let(:body)         { 'the-file-body' }
  let(:content_type) { 'image/jpeg' }
  subject            { URLTempfile.new(url) }

  def stub_http_request(status)
    stub_request(:get, url).to_return(
      :body    => body,
      :status  => status,
      :headers => { 'Content-Type' => content_type }
    )
  end

  context "when the request has a 200 status code" do
    before(:each) { stub_http_request(200) }

    its(:content_type)      { should == content_type }
    its(:original_filename) { should == path_end }

    it 'has the correct content' do
      subject.rewind
      subject.read.should == body
    end
  end

  [404, 500, 301].each do |status|
    context "when the request has a #{status} status code" do
      before(:each) { stub_http_request(status) }

      it 'raises an error' do
        expect { subject }.to raise_error(URLTempfile::UnsuccessfulHTTPResponse)
      end
    end
  end
end
