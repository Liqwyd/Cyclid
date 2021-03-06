# frozen_string_literal: true
require 'spec_helper'

describe Cyclid::API::Plugins::Debian do
  # Provide a stub transport
  class TestTransport < Cyclid::API::Plugins::Transport
    attr_reader :exit_code, :cmd

    def initialize(_args = {})
      @exit_code = 0
    end

    def exec(cmd, args = {})
      @cmd = cmd
      @path = args[:path]
      true
    end

    register_plugin 'test'
  end

  before :all do
    @transport = TestTransport.new
    @buildhost = Cyclid::API::Plugins::BuildHost.new(hostname: 'test.example.com')
  end

  it 'should create a new instance' do
    expect{ Cyclid::API::Plugins::Debian.new }.to_not raise_error
  end

  it 'should prepare a host with an empty environment and packages list' do
    provisioner = nil
    expect{ provisioner = Cyclid::API::Plugins::Debian.new }.to_not raise_error
    expect{ provisioner.prepare(@transport, @buildhost) }.to_not raise_error
  end

  context 'adding repositories' do
    it 'should add a valid HTTP repository' do
      env = { repos: [{ url: 'http://test.example.com/example/test',
                        components: 'main test' }] }

      provisioner = nil
      expect{ provisioner = Cyclid::API::Plugins::Debian.new }.to_not raise_error
      expect{ provisioner.prepare(@transport, @buildhost, env) }.to_not raise_error
      expect(@transport.cmd).to eq('apt-get update -q')
    end

    it 'should add a valid HTTPS repository' do
      env = { repos: [{ url: 'https://test.example.com/example/test',
                        components: 'main test' }] }

      provisioner = nil
      expect{ provisioner = Cyclid::API::Plugins::Debian.new }.to_not raise_error
      expect{ provisioner.prepare(@transport, @buildhost, env) }.to_not raise_error
      expect(@transport.cmd).to eq('apt-get update -q')
    end

    it 'should add a valid repository with a GPG key' do
      env = { repos: [{ url: 'http://test.example.com/example/test',
                        components: 'main test',
                        key_id: 'ABCDEFGH' }] }

      provisioner = nil
      expect{ provisioner = Cyclid::API::Plugins::Debian.new }.to_not raise_error
      expect{ provisioner.prepare(@transport, @buildhost, env) }.to_not raise_error
      expect(@transport.cmd).to eq('apt-get update -q')
    end

    it "should fail if the repository doesn't specify any components" do
      env = { repos: [{ url: 'http://test.example.com/example/test' }] }

      provisioner = nil
      expect{ provisioner = Cyclid::API::Plugins::Debian.new }.to_not raise_error
      expect{ provisioner.prepare(@transport, @buildhost, env) }.to raise_error
    end
  end

  it 'should prepare a host with a list of packages' do
    env = { packages: ['package'] }

    provisioner = nil
    expect{ provisioner = Cyclid::API::Plugins::Debian.new }.to_not raise_error
    expect{ provisioner.prepare(@transport, @buildhost, env) }.to_not raise_error
    expect(@transport.cmd).to eq('apt-get install -q -y package')
  end
end
