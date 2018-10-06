Pod::Spec.new do |s|
s.name             = "Networking"
s.version          = "4.4.0"
s.summary          = "Simple HTTP Networking in Swift a NSURLSession wrapper with image caching support"
s.description  = <<-EOS
Simple NSURLSession wrapper with support for image caching and faking network requests

- Super friendly API
- Singleton free
- No external dependencies
- Optimized for unit testing
- Minimal implementation
- Simple request cancellation
- Fake requests easily (mocking/stubbing)
- Runs synchronously in automatic testing environments
- Image downloading and caching
- Free
EOS
s.homepage         = "https://github.com/3lvis/Networking"
s.license          = 'MIT'
s.author           = { "Elvis Nuñez" => "elvisnunez@me.com" }
s.source           = { git: "https://github.com/3lvis/Networking.git", tag: s.version.to_s }
s.social_media_url = 'https://twitter.com/3lvis'
s.ios.deployment_target = '9.0'
s.osx.deployment_target = '10.11'
s.watchos.deployment_target = '2.0'
s.tvos.deployment_target = '9.0'
s.requires_arc     = true
s.source_files     = 'Sources/**/*'
s.frameworks       = 'Foundation'
s.swift_version    = '4.2'
end
