MRuby::Build.new do |conf|
  conf.toolchain :clang
  conf.gembox 'default'
  conf.enable_bintest
  conf.enable_test
end
