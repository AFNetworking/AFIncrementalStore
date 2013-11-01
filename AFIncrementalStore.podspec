Pod::Spec.new do |s|
  s.name         = "AFIncrementalStore"
  s.version      = "0.5.1"
  s.summary      = "Core Data Persistence with AFNetworking, Done Right."
  s.homepage     = "https://github.com/AFNetworking/AFIncrementalStore"
  s.author       = { "Mattt Thompson" => "m@mattt.me" }
  s.license      = 'MIT'

  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'

  s.source       = { :git => "https://github.com/AFNetworking/AFIncrementalStore.git", :tag => "0.5.1" }
  s.source_files = 'AFIncrementalStore/*.{h,m}'

  s.framework  = 'CoreData'

  s.requires_arc = true

  s.dependency 'AFNetworking', '~> 1.3.2'
  s.dependency 'InflectorKit'
  s.dependency 'TransformerKit'

  s.prefix_header_contents = <<-EOS
#import <Availability.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED
  #import <SystemConfiguration/SystemConfiguration.h>
  #import <MobileCoreServices/MobileCoreServices.h>
  #import <Security/Security.h>
#else
  #import <SystemConfiguration/SystemConfiguration.h>
  #import <CoreServices/CoreServices.h>
  #import <Security/Security.h>
#endif
EOS
end
