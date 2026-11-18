//
//  AvatarAndUsernameTests.swift
//  RECORDTests
//
//  Two client-side rules that have to agree with a database constraint. If
//  either drifts, the failure shows up as a rejected upload or a confusing
//  signup error rather than as anything obviously wrong in the app — so pin
//  them here.
//

import Testing
import Foundation
import UIKit
@testable import RECORD

@Suite("Avatar encoding")
struct AvatarEncodingTests {

    /// A plain coloured image at an arbitrary, deliberately non-square size.
    private func image(width: CGFloat, height: CGFloat) -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                          format: format).image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return img.pngData()!
    }

    @Test("a wide photo comes back square")
    func cropsToSquare() throws {
        let data = try #require(ProfileView.jpegSquare(from: image(width: 4032, height: 3024)))
        let out  = try #require(UIImage(data: data))
        #expect(out.size.width == out.size.height)
    }

    @Test("a tall photo comes back square")
    func cropsTallToSquare() throws {
        let data = try #require(ProfileView.jpegSquare(from: image(width: 1080, height: 1920)))
        let out  = try #require(UIImage(data: data))
        #expect(out.size.width == out.size.height)
    }

    @Test("downscales to 512 points at most")
    func capsTheLongEdge() throws {
        let data = try #require(ProfileView.jpegSquare(from: image(width: 4032, height: 3024)))
        let out  = try #require(UIImage(data: data))
        #expect(out.size.width <= 512)
    }

    @Test("a small photo is not blown up")
    func doesNotUpscale() throws {
        let data = try #require(ProfileView.jpegSquare(from: image(width: 120, height: 90)))
        let out  = try #require(UIImage(data: data))
        #expect(out.size.width == 90, "the short edge sets the square")
    }

    @Test("stays under the 2 MiB the avatars bucket allows")
    func fitsTheBucketLimit() throws {
        // A 12MP photo is the realistic worst case off an iPhone camera.
        let data = try #require(ProfileView.jpegSquare(from: image(width: 4032, height: 3024)))
        #expect(data.count < 2 * 1024 * 1024)
    }

    @Test("produces real JPEG bytes, not a renamed HEIC")
    func isActuallyJPEG() throws {
        // The bucket's allowed_mime_types is image/jpeg only, and the picker
        // hands back HEIC on an iPhone — so this is the check that matters.
        let data = try #require(ProfileView.jpegSquare(from: image(width: 600, height: 600)))
        #expect(data.prefix(3) == Data([0xFF, 0xD8, 0xFF]), "JPEG magic number")
    }

    @Test("refuses data that isn't an image")
    func rejectsNonImage() {
        #expect(ProfileView.jpegSquare(from: Data("not an image".utf8)) == nil)
        #expect(ProfileView.jpegSquare(from: Data()) == nil)
    }
}

@Suite("Username shape")
struct UsernameShapeTests {

    @Test("accepts what profiles_username_shape accepts",
          arguments: ["ab", "amir", "AMIR", "Donny", "testing",
                      "a_b.c", "user.name_1", "abcdefghijklmnopqrst"])
    func accepts(name: String) {
        #expect(AuthView.isWellFormed(name))
    }

    @Test("rejects what the constraint rejects",
          arguments: ["", "a", "abcdefghijklmnopqrstu",
                      "has space", "emoji🙂", "semi;colon", "quote'", "dash-dash",
                      "slash/", "at@sign"])
    func rejects(name: String) {
        #expect(!AuthView.isWellFormed(name))
    }

    @Test("the boundary lengths are 2 and 20")
    func boundaries() {
        #expect(!AuthView.isWellFormed(String(repeating: "a", count: 1)))
        #expect(AuthView.isWellFormed(String(repeating: "a", count: 2)))
        #expect(AuthView.isWellFormed(String(repeating: "a", count: 20)))
        #expect(!AuthView.isWellFormed(String(repeating: "a", count: 21)))
    }
}
