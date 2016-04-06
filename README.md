Project is abandoned until such a time Apple decides to allow better permanent local storage solutions.

This application aims to make displaying a fullscreen slideshow on tvOS.
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
	],
	"countdowns":[
		{
			"day": 1,
			"hour": 14,
			"minute": 30,
			"duration": 30
		}
	]
}
```

The JSON response and all resources must be served over https unless you modify
the project in xcode to allow the application to use http.

Countdowns that overlap will show the first item from the array.
Countdowns display in the top right corner of the slideshow.
Days are the day of the week from 1 to 7 with Sunday being 1.
The hour and minute are when the countdown should be 0, not when the countdown starts.
The hour should be in military time. Currently the timezone is whatever the client computer is set to.
The duration is in minutes and is not at this point fractional.
Countdowns that overlap days have not been tested.

This application can handle jpeg and png images and any video format supported
by Apple's AV Foundation. This application does not support subtitles or captions
in the videos.

This project makes use of the following Cocoapods:

```
pod 'FileKit', '~> 2.0.0'
pod 'Alamofire', '~> 3.0'
pod 'SwiftyJSON', :git => 'https://github.com/SwiftyJSON/SwiftyJSON.git'
```

So as with any project using Cocoapods, you should use the xcworkspace instead of the xcodeproj.
