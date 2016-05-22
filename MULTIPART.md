# Multipart

## Table of Contents

* [Introduction](#introduction)
* [Content type](#content-type)

## Introduction

A multipart upload consists in appending one or several [FormPart](https://github.com/3lvis/Networking/blob/master/Sources/FormPart.swift) items to a request. The simplest multipart request would look like this.

```swift
let networking = Networking(baseURL: "https://example.com")
let imageData = UIImagePNGRepresentation(imageToUpload)!
let part = FormPart(data: imageData, parameterName: "file", filename: "selfie.png")
networking.POST("/image/upload", part: part) { JSON, error in
    // do something
}
```

If you need to use several parts or append other parameters than aren't files, you can do it like this:

```swift
let networking = Networking(baseURL: "https://example.com")
let part1 = FormPart(data: imageData1, parameterName: "file1", filename: "selfie1.png")
let part2 = FormPart(data: imageData2, parameterName: "file2", filename: "selfie2.png")
let parameters = ["username" : "3lvis"]
networking.POST("/image/upload", parts: [part1, part2], parameters: parameters) { JSON, error in
    // Do something
}
```

## Content type

`FormPart` uses `FormPartType` to generate the content type for each part. The default `FormPartType` is `.Data` which adds the `application/octet-stream` to your part. If you want to use a content type that is not available between the existing `FormPartType`, you can use `.Custom("your-content-type)`.
