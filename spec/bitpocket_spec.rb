require 'fileutils'

BP_BIN_PATH = File.join(File.dirname(__FILE__), '..', 'bin', 'bitpocket')
RSYNC_STUB_BIN_PATH = File.join(File.dirname(__FILE__), 'bin')
PATH = "#{RSYNC_STUB_BIN_PATH}:#{ENV['PATH']}"

def sync(opts={})
  system "CALLBACK=#{opts[:callback]} PATH=#{PATH} sh #{BP_BIN_PATH} >/dev/null"
end

def local_path(fname)
  "#{@local_dir}/#{fname}"
end

def remote_path(fname)
  "#{@remote_dir}/#{fname}"
end

def touch(path)
  FileUtils.touch(path)
end

def cat(content, path)
  File.open(path, 'w') { |f| f.write content }
end

def rm(path)
  FileUtils.rm(path)
end

describe 'bitpocket' do
  before(:all) do
    @tmp_dir = "/tmp/bitpocket-test-#{Time.now.to_i}"
    @test_case = { :num => 0 }
  end

  before do
    @test_case[:num] += 1
    test_case_dir = File.join(@tmp_dir, @test_case[:num].to_s)
    @local_dir = File.join(test_case_dir, 'local')
    @remote_dir = File.join(test_case_dir, 'remote')
    FileUtils.mkdir_p(@local_dir)
    FileUtils.mkdir_p(@remote_dir)
    Dir.chdir(@local_dir)
    FileUtils.mkdir_p("#{@local_dir}/.bitpocket")
    cat 'REMOTE=../remote', local_path('.bitpocket/config')
  end

  let(:content) { 'foo' }

  it 'does not sync ignored files' do
    cat "/a\n/b", local_path('.bitpocket/exclude')
    touch local_path('a')
    touch remote_path('b')

    sync

    File.exist?(local_path('a')).should be(true)
    File.exist?(remote_path('a')).should be(false)
    File.exist?(local_path('b')).should be(false)
    File.exist?(remote_path('b')).should be(true)
  end

  it 'does not sync .bitpocket dir' do
    sync

    File.exist?(remote_path('.bitpocket')).should be(false)
  end

  it 'does not remove new local files' do
    touch local_path('a')

    sync

    File.exist?(local_path('a')).should be(true)
  end

  it 'does not remove new local files created in parallel to previous sync' do
    sync(:callback => :add_after)
    sync

    File.exist?(local_path('after')).should be(true)
  end

  it 'does not bring back removed local files' do
    touch local_path('a')
    touch remote_path('a')
    sync
    rm local_path('a')

    sync

    File.exist?(local_path('a')).should be(false)
  end

  it 'does not bring back removed local files deleted in parallel to previous sync' do
    touch local_path('after')
    sync
    sync(:callback => :remove_after)
    sync

    File.exist?(local_path('after')).should be(false)
  end

  it 'transfers new file from local to remote' do
    touch local_path('a')

    sync

    File.exist?(local_path('a')).should be(true)
    File.exist?(remote_path('a')).should be(true)
  end

  it 'transfers updated file from local to remote' do
    touch local_path('a')
    touch remote_path('a')
    sync
    system "touch -d '00:00' #{remote_path('a')}"
    cat content, local_path('a')

    sync

    File.read(local_path('a')).should == content
    File.read(remote_path('a')).should == content
  end

  it 'transfers new file from remote to local' do
    touch remote_path('a')

    sync

    File.exist?(local_path('a')).should be(true)
    File.exist?(remote_path('a')).should be(true)
  end

  it 'transfers updated file from remote to local' do
    touch local_path('a')
    touch remote_path('a')
    sync
    cat content, remote_path('a')

    sync

    File.read(local_path('a')).should == content
    File.read(remote_path('a')).should == content
  end

  it 'removes file from remote if locally deleted' do
    touch local_path('a')
    touch remote_path('a')
    sync
    rm local_path('a')

    sync

    File.exist?(local_path('a')).should be(false)
    File.exist?(remote_path('a')).should be(false)
  end

  it 'removes file from local if remotely deleted' do
    touch local_path('a')
    touch remote_path('a')
    sync
    rm remote_path('a')

    sync

    File.exist?(local_path('a')).should be(false)
    File.exist?(remote_path('a')).should be(false)
  end
end
