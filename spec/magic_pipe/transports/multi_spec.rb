RSpec.describe MagicPipe::Transports::Multi do
  let(:config) do
    MagicPipe::Config.new do |c|
      c.transports = [:https, :sqs]
      c.https_transport_options = {} # let the defaults apply
    end
  end

  let(:metrics) { MagicPipe::Metrics.new(config.metrics_client) }

  subject do
    described_class.new(config, metrics)
  end


  specify "a Multi transport contains nested transports" do
    expect(MagicPipe::Transports::Https).to receive(:new).with(config, metrics)
    expect(MagicPipe::Transports::Sqs).to receive(:new).with(config, metrics)
    subject
  end


  describe "submit" do
    let(:payload) { "an encoded payload" }
    let(:metadata) do
      {
        topic: "topic",
        producer: "producer_name",
        time: Time.now.utc.to_i,
        mime: "none"
      }
    end

    def perform
      subject.submit(payload, metadata)
    end

    it "forwards the payload to all the nested transports" do
      expect_any_instance_of(MagicPipe::Transports::Https).to receive(:submit).with(payload, metadata)
      expect_any_instance_of(MagicPipe::Transports::Sqs).to receive(:submit).with(payload, metadata)
      perform
    end

    describe "if one of the transports raises an error" do
      before do
        expect_any_instance_of(MagicPipe::Transports::Https).to receive(:submit) do
          raise "oh no"
        end
      end

      it "logs the error and doesn't halt the pipeline" do
        expect_any_instance_of(MagicPipe::Transports::Sqs).to receive(:submit).with(payload, metadata)

        expect {
          perform
        }.to output(
          %r{Transports::Multi, error submitting with MagicPipe::Transports::Https}
        ).to_stdout
      end
    end
  end
end
