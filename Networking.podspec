Pod::Spec.new do |s|
s.name             = "Networking"
s.version          = "0.2.0"
s.summary          = "Networking library"
s.homepage         = "https://github.com/3lvis/Networking"
s.license          = 'MIT'
s.author           = { "Elvis Nuñez" => "elvisnunez@me.com" }
s.source           = { git: "https://github.com/3lvis/Networking.git", tag: s.version.to_s }
s.social_media_url = 'https://twitter.com/3lvis'
s.platform         = :ios, '7.0'
s.requires_arc     = true
s.source_files     = 'Source/**/*'
s.frameworks       = 'UIKit', 'Foundation'
s.dependency 'NSObject-HYPTesting', '~> 1.2'
end
