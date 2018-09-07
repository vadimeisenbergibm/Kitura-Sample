/**
 * Copyright IBM Corporation 2018
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import SwiftJWT
import KituraContracts
import Foundation
import FileKit
import Kitura
import LoggerAPI

func initializeJWTRoutes(app: App) {
	
	app.router.post("/static/create_token", handler: postFormHandler)
	app.router.get("/static/token_generated") { request, response, next in
		
	}
}

func postFormHandler(jwtMiddleware: JWTMiddleware, respondWith: (TokenDetails?, RequestError?) -> Void) {
	respondWith(TokenDetails(name: jwtMiddleware.name, favourite: jwtMiddleware.favourite), nil)
}

func createToken(token: TokenDetails) -> String? {
	
	let localURL = FileKit.projectFolderURL
	
	enum JWTError {
		case keyNotFound
	}
	
	// Get the private key data into a Swift variable
	let fileData = try! Data(contentsOf: localURL.appendingPathComponent("/JWT/rsa_private_key", isDirectory: false))
	
	// Set expiration time for today's date plus one week (in seconds)
	let expirationDate = Double(Date().timeIntervalSince1970 + 604800)

	
	//Create JWT and use token data to create claims
	var jwt = JWT(header: Header([.typ:"JWT", .alg:"rs256"]), claims: Claims([.name:"JWT"]))
	jwt.claims["username"] = token.name
	jwt.claims["favouriteNumber"] = String(token.favourite)
	jwt.claims[.iat] = String(Date().timeIntervalSince1970)
	jwt.claims[.exp] = String(expirationDate)
	
	// Sign JWT using the private key. Remember, this isn't encrypted, just signed.
	let signedJWT = try! jwt.sign(using: .rs256(fileData, .privateKey))
	
	return signedJWT
}

struct TokenDetails: Codable, QueryParams {
	let name: String
	let favourite: Int
}

struct JWTMiddleware: TypeSafeMiddleware {
	
//	let token: TokenDetails
	
	let name: String
	let favourite: Int
	
	static func handle(request: RouterRequest, response: RouterResponse, completion: @escaping (JWTMiddleware?, RequestError?) -> Void) {
		
		let token: TokenDetails!
		
		do {
			token = try request.read(as: TokenDetails.self)
		} catch {
			Log.error("Error: could not decode \(error)")
			return completion(nil, .badRequest)
		}
		
		// Create the JWT
		let jwt = createToken(token: token)
		
		// Make a cookie to save to the JWT to the browsers storage
		let cookie = HTTPCookie(properties: [HTTPCookiePropertyKey.name: "JWT-KituraTest", HTTPCookiePropertyKey.value: jwt!, HTTPCookiePropertyKey.domain: "localhost", HTTPCookiePropertyKey.path: "/"])

		response.cookies[cookie!.name] = cookie
		
		let selfinstance = JWTMiddleware(token: token)
		
		return completion(selfinstance, nil)
	}
	
	init(token: TokenDetails) {
		self.name = token.name
		self.favourite = token.favourite
	}
	
}

extension Router {
	public func post<T: TypeSafeMiddleware, O: Codable>(
		_ route: String,
		handler: @escaping (T, @escaping CodableResultClosure<O>) -> Void
		) {
		post(route) { request, response, next in
			Log.info("we did my custom one")

			T.handle(request: request, response: response) { (typeSafeMiddleware: T?, error: RequestError?) in
				guard let typeSafeMiddleware = typeSafeMiddleware else {
					response.status(CodableHelpers.httpStatusCode(from: error ?? .internalServerError))
					return next()
				}
				handler(typeSafeMiddleware, CodableHelpers.constructOutResultHandler(successStatus: .created, response: response, completion: next))
			}
		}
	}
}
