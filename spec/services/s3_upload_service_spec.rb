# frozen_string_literal: true

require 'rails_helper'

RSpec.describe S3UploadService do
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:presigner) { instance_double(Aws::S3::Presigner) }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(Aws::S3::Presigner).to receive(:new).and_return(presigner)

    stub_const('ENV', ENV.to_h.merge(
      'SUPABASE_S3_ACCESS_KEY' => 'test-key',
      'SUPABASE_S3_SECRET_KEY' => 'test-secret',
      'SUPABASE_S3_ENDPOINT'   => 'https://test.storage.supabase.co/storage/v1/s3',
      'SUPABASE_S3_BUCKET'     => 'test-bucket'
    ))
  end

  describe '#upload' do
    let(:file) do
      instance_double(
        ActionDispatch::Http::UploadedFile,
        content_type: 'image/jpeg',
        size: 1024,
        original_filename: 'avatar.jpg',
        read: 'binary-content'
      )
    end

    context 'with a valid file' do
      before do
        allow(s3_client).to receive(:put_object).and_return(double('put_object_response'))
      end

      it 'returns a hash with key, filename, content_type, and size' do
        result = described_class.new.upload(file)

        expect(result).to include(:key, :filename, :content_type, :size)
      end

      it 'returns the correct filename and content_type' do
        result = described_class.new.upload(file)

        expect(result[:filename]).to eq('avatar.jpg')
        expect(result[:content_type]).to eq('image/jpeg')
      end

      it 'returns the file size' do
        result = described_class.new.upload(file)
        expect(result[:size]).to eq(1024)
      end

      it 'generates a key with the correct prefix' do
        result = described_class.new.upload(file, prefix: 'orgs/123/logo')
        expect(result[:key]).to start_with('orgs/123/logo/')
      end
    end

    context 'with a disallowed content type' do
      let(:invalid_file) do
        instance_double(
          ActionDispatch::Http::UploadedFile,
          content_type: 'application/exe',
          size: 512,
          original_filename: 'malware.exe',
          read: ''
        )
      end

      it 'raises ArgumentError' do
        expect { described_class.new.upload(invalid_file) }.to raise_error(ArgumentError, /not allowed/)
      end
    end

    context 'with a file exceeding MAX_SIZE_BYTES' do
      let(:oversized_file) do
        instance_double(
          ActionDispatch::Http::UploadedFile,
          content_type: 'image/png',
          size: 15 * 1024 * 1024, # 15 MB
          original_filename: 'big.png',
          read: ''
        )
      end

      it 'raises ArgumentError' do
        expect { described_class.new.upload(oversized_file) }.to raise_error(ArgumentError, /too large/)
      end
    end
  end

  describe '#signed_url' do
    context 'when presigning succeeds' do
      before do
        allow(presigner).to receive(:presigned_url)
          .and_return('https://signed.url/key?signature=abc')
      end

      it 'returns a non-nil URL string' do
        url = described_class.new.signed_url('support/some-uuid.jpg')
        expect(url).to be_a(String)
        expect(url).to include('signed.url')
      end
    end

    context 'when presigning raises an error' do
      before do
        allow(presigner).to receive(:presigned_url).and_raise(StandardError, 'S3 error')
      end

      it 'returns nil instead of raising' do
        url = described_class.new.signed_url('support/some-uuid.jpg')
        expect(url).to be_nil
      end
    end
  end

  describe '#public_url' do
    it 'returns a URL containing the bucket and key' do
      url = described_class.new.public_url('support/my-file.jpg')
      expect(url).to include('test-bucket')
      expect(url).to include('support/my-file.jpg')
    end

    it 'constructs the Supabase public URL format' do
      url = described_class.new.public_url('orgs/123/logo.png')
      expect(url).to match(%r{/object/public/})
    end
  end
end
