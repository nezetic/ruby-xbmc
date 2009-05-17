Gem::Specification.new do |s|
  s.name = %q{ruby-xbmc}
  s.version = '0.1.1'
  s.date = %q{2009-05-15}
  s.authors = ["Cedric TESSIER"]
  s.email = "nezetic at gmail d o t com"
  s.summary = %q{ruby-xbmc is a ruby wrapper for the XBMC Web Server HTTP API}
  s.homepage = %q{http://github.com/nezetic/ruby-xbmc}
  s.description = %q{ruby-xbmc is a ruby wrapper for the XBMC Web Server HTTP API.
  
  It provides a remote access to any XBMC running on the local network,
  in a simple way (methods follow the ones from XBMC API).}
  s.files = [ "README", "lib/ruby-xbmc.rb"]
  s.has_rdoc = true
  s.require_paths = ["lib"]
  s.add_dependency('hpricot', '>= 0.6')
end 

