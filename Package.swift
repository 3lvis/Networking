// swift-tools-version:4.0
import PackageDescription

let package = Package(
	name: "Networking",
	products: [
		.library(name: "Networking", targets: ["Networking"]),
		],
	targets: [
		.target(
			name: "Networking",
			dependencies: [],
			path: "./Sources"),
	]
)
