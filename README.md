This application aims to make displaying a fullscreen slideshow on OS X 10.11+
simple by receiving a JSON response from a server with the following structure:

```
{
	"items":[
		{
			"type": "image",
			"url": "https://example.com/resource.jpg",
			"md5sum": "1fda9e22f90b977119627c508567b74e",
			"filesize": 1290906
		},
		{
			"type": "video",
			"url": "https://example.com/resource.mp4",
			"md5sum": "1c35f040c23a2015d303df9e812485c2",
			"filesize": 2159191
		}
	]
}
```

The JSON response and all resources must be served over https unless you modify
the project in xcode to allow the application to use http.

This project makes use of the following Cocoapods:

```
pod 'FileKit', '~> 2.0.0'
pod 'Alamofire', '~> 3.0'
pod 'SwiftyJSON', :git => 'https://github.com/SwiftyJSON/SwiftyJSON.git'
```

So as with any project using Cocoapods, you should use the xcworkspace instead of the xcodeproj.
