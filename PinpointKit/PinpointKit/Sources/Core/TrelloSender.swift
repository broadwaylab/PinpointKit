//
//  TrelloSender.swift
//  PinpointKit
//
//  Created by Michael Fellows on 11/16/16.
//  Copyright © 2016 Lickability. All rights reserved.
//

import Foundation

public class TrelloSender: NSObject, Sender {

    /// A delegate that is informed of successful or failed feedback sending.
    weak open var delegate: SenderDelegate?

    private var feedback: Feedback?

    /// A success in sending feedback.
    enum Success: SuccessType {
        /// The email was sent.
        case sent
    }

    /// An error in sending feedback.
    enum Error: Swift.Error {

        /// An unknown error occured.
        case unknown

        /// No view controller was provided for presentation.
        case noViewControllerProvided

        /// The screenshot failed to encode.
        case imageEncoding

        /// Invalid URL
        case invalidURL

        /// The text failed to encode.
        case textEncoding

        /// Failed to upload to server
        case upload
    }

    // Trello API key
    private var key: String!

    // Trello API token
    private var token: String!

    // listId for the list we're posting to.
    private var listId: String!


    public init(key: String, token: String, listId: String) {
        self.key = key
        self.listId = listId
        self.token = token
    }

    /**
     Sends the feedback using the provided view controller as a presenting view controller.

     - parameter feedback:       The feedback to send.
     - parameter viewController: The view controller from which to present any of the sender’s necessary views.
     */
    open func send(_ feedback: Feedback, from viewController: UIViewController?) {
        guard let viewController = viewController else {
            fail(with: .noViewControllerProvided); return
        }

        let image = feedback.screenshot.preferredImage
        guard let imageData = UIImageJPEGRepresentation(image, 0.8) else {
            fail(with: .imageEncoding); return
        }

        let urlString = "https://api.trello.com/1/cards?idList=\(listId)&due=null&key=\(key)&token=\(token)"
        guard let url = URL(string: urlString) else {
            fail(with: .invalidURL); return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "---------------------------14737809831466499882746641449"
        let contentType = "multipart/form-data; boundary=\(boundary)"
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")

        var body = Data()

        guard let encodedBoundary = "\r\n--\(boundary)\r\n".data(using: .utf8) else {
            fail(with: .textEncoding); return
        }

        body.append(encodedBoundary)

        guard let encodedDisposition = "Content-Disposition: form-data; name=\"file\"; filename=\"img.jpg\"\\r\n".data(using: .utf8) else {
            fail(with: .textEncoding); return
        }

        body.append(encodedDisposition)

        guard let encodedContentType = "Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8) else {
            fail(with: .textEncoding); return
        }

        body.append(encodedContentType)

        // Append image data
        body.append(imageData)

        // Append the boundary again to show the end of the content.
        body.append(encodedBoundary)

        request.httpBody = body


        let session = URLSession.shared
        let uploadTask = session.uploadTask(with: request, from: nil) { (data, response, error) in
            guard let _ = error else {
                self.fail(with: .upload); return
            }

            self.succeed(with: .sent)
        }

        uploadTask.resume()
        viewController.dismiss(animated: true, completion: nil)
    }

    // MARK: - TrelloSender

    fileprivate func fail(with error: Error) {
        delegate?.sender(self, didFailToSend: feedback, error: error)
        feedback = nil
    }

    fileprivate func succeed(with success: Success) {
        delegate?.sender(self, didSend: feedback, success: success)
        feedback = nil
    }
}
