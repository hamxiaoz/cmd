require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'
require 'rake/contrib/sshpublisher'

require 'date'
require 'rbconfig'

PKG_NAME         = 'cmd'
PKG_VERSION      = '0.7.2'
PKG_FILE_NAME    = "#{PKG_NAME}-#{PKG_VERSION}"
PKG_DESTINATION  = "../#{PKG_NAME}"
PKG_AUTHOR       = 'Marcel Molina Jr.' 
PKG_AUTHOR_EMAIL = 'marcel@vernix.org'
PKG_HOMEPAGE     = 'http://cmd.rubyforge.org'
PKG_REMOTE_PATH  = "www/code/#{PKG_NAME}"
PKG_REMOTE_HOST  = 'vernix.org' 
PKG_REMOTE_USER  = 'marcel'
PKG_ARCHIVES_DIR = 'download'
PKG_DOC_DIR      = 'rdoc'

BASE_DIRS   = %w( lib example test )

desc "Default Task"
task :default => [ :test ]

desc "Run unit tests"
task :test do
  # Rake's TestTask seems to mess with my IO streams so I'm doing this the lame
  # way.
  system 'ruby test/tc_*.rb'
end

# Generate documentation ------------------------------------------------------

RDOC_FILES = [
  'AUTHORS',
  'CHANGELOG',  
  'INSTALL',  
  'README',  
  'THANKS',  
  'TODO', 
  'lib/cmd.rb'
] 

desc "Generate documentation"
Rake::RDocTask.new do |rd|
  rd.main = 'README'
  rd.title = PKG_NAME
  rd.rdoc_dir = PKG_DOC_DIR
  rd.rdoc_files.include(RDOC_FILES)
  rd.options << '--inline-source'
  rd.options << '--line-numbers'
end


# Generate GEM ----------------------------------------------------------------

PKG_FILES = FileList[
  '[a-zA-Z]*',
  'lib/**', 
  'test/**', 
  'example/**'
]

spec = Gem::Specification.new do |s|
  s.name    = PKG_NAME
  s.version = PKG_VERSION
  s.summary = "A generic class to build line-oriented command interpreters."
  s.description = s.summary 

  s.files = PKG_FILES.to_a.delete_if {|f| f.include?('.svn')}
  s.require_path = 'lib'

  s.has_rdoc = true
  s.extra_rdoc_files = RDOC_FILES 
  s.rdoc_options << '--main'  << 'README' << 
                    '--title' << PKG_NAME << 
                    '--line-numbers'      <<
                    '--inline-source'

  s.test_files = Dir.glob('test/tc_*.rb')

  s.author   = PKG_AUTHOR 
  s.email    = PKG_AUTHOR_EMAIL 
  s.homepage = PKG_HOMEPAGE 
  s.rubyforge_project = PKG_NAME
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip     = true
  pkg.need_tar_gz  = true
  pkg.need_tar_bz2 = true
  pkg.package_dir  = PKG_ARCHIVES_DIR 
end

# Support Tasks ---------------------------------------------------------------

def egrep(pattern)
  Dir['**/*.rb'].each do |fn|
    count = 0
    open(fn) do |f|
      while line = f.gets
  count += 1
  if line =~ pattern
    puts "#{fn}:#{count}:#{line}"
  end
      end
    end
  end
end

desc "Look for TODO and FIXME tags in the code"
task :todo do
  egrep /#.*(FIXME|TODO|XXX)/
end

# Push Release ----------------------------------------------------------------

desc "Push current archives to release server"
task :push_package => [ :package ] do 
  Rake::SshDirPublisher.new(
    "#{PKG_REMOTE_USER}@#{PKG_REMOTE_HOST}",
    "#{PKG_REMOTE_PATH}/#{PKG_ARCHIVES_DIR}",
    PKG_ARCHIVES_DIR
  ).upload
end

desc "Push current rdoc to release server"
task :push_rdoc => [ :rdoc ] do
  Rake::SshDirPublisher.new(
    "#{PKG_REMOTE_USER}@#{PKG_REMOTE_HOST}",
    "#{PKG_REMOTE_PATH}/#{PKG_DOC_DIR}",
    PKG_DOC_DIR
  ).upload
end

desc "Push current version up to release server"
task :push_release => [ :push_rdoc, :push_package ] 
