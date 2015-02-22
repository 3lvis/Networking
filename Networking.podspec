Pod::Spec.new do |s|
s.name             = "Networking"
s.version          = "0.1"
s.summary          = "Networking library"
s.homepage         = "https://github.com/NSElvis/Networking"
s.license          = 'MIT'
s.author           = { "Elvis Nuñez" => "hello@nselvis.com" }
s.source           = { git: "https://github.com/NSElvis/Networking.git", tag: s.version.to_s }
s.social_media_url = 'https://twitter.com/NSElvis'

s.platform         = :ios, '7.0'
s.requires_arc     = true

s.source_files     = 'Source/**/*'

# s.frameworks = 'UIKit', 'MapKit'
# s.dependency 'AFNetworking', '~> 2.3'
end
