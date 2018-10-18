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
	
    // set up JWT encoder
    let localURL = FileKit.projectFolderURL
    guard let privateKey = try? Data(contentsOf: localURL.appendingPathComponent("/JWT/rsa_private_key", isDirectory: false)) else {
        Log.error("Failed to read private key from file")
        return
    }
    guard let publicKey = try? Data(contentsOf: localURL.appendingPathComponent("/JWT/rsa_public_key", isDirectory: false)) else {
        Log.error("Failed to read public key from file")
        return
    }
    app.router.encoders[MediaType(type: .application, subType: "jwt")] = {_ in return JWTEncoder(algorithm: .rs256(privateKey, .privateKey)) }

    app.router.decoders[MediaType(type: .application, subType: "jwt")] = {
        (requestHeaders: Headers) in
        let selectedKey = HolderOfKeys.getDecodingKey(keyNumber: Int(requestHeaders["keyNumber"] ?? "") ?? 0)
        return JWTDecoder(algorithm: .rs256(selectedKey, .publicKey))
    }

    let dummyKey = Data(capacity: 0)
    HolderOfKeys.keys.append(dummyKey)
    HolderOfKeys.keys.append(publicKey)

	app.router.post("/jwt/create_token", handler: app.postFormHandler)
    app.router.get("/jwt/protected", handler: app.protectedHandler)
    // This route accepts JSON or URLEncoded POST requests
    app.router.post("/jwtcoder", handler: app.jwtCoder)
}

class HolderOfKeys {
    static var keys: [Data] = []
    static let dummyKey = Data(capacity: 0)

    class func getDecodingKey(keyNumber: Int) -> Data {
        return (keyNumber >= 0 && keyNumber < keys.count ? keys[keyNumber] : dummyKey)
    }
}

extension App {

    func postFormHandler(claims: TokenDetails, respondWith: (JWT<TokenDetails>?, RequestError?) -> Void) {
        let datedClaim = TokenDetails(iat: Date(), exp: Date(timeIntervalSinceNow: 3600), name: claims.name, favourite: claims.favourite)
        let jwt = JWT(header: Header(typ: "JWT", alg: "rs256"), claims: datedClaim)
        respondWith(jwt, nil)
    }
    
    func protectedHandler(typeSafeJWT: TypeSafeJWT<TokenDetails>, respondWith: (JWT<TokenDetails>?, RequestError?) -> Void) {
        guard case .success = typeSafeJWT.jwt.validateClaims() else {
            return respondWith(nil, .badRequest)
        }
        respondWith(typeSafeJWT.jwt, nil)
    }
    
    func jwtCoder(inJWT: JWT<TokenDetails>, respondwith: (JWT<TokenDetails>?, RequestError?) -> Void ) {
        print("Got a JWT")
        respondwith(inJWT, nil)
    }
}

struct TokenDetails: Codable, QueryParams, Claims {
    // Standard JWT Fields
    var iat: Date?
    var exp: Date?
    
    let name: String
    let favourite: Int
}

struct TypeSafeJWT<C: Claims>: TypeSafeMiddleware {
    let jwt: JWT<C>
    // Duplicate of Router.decoders for application/jwt
    static func decoder(headers: Headers) -> JWTDecoder? {
        let selectedKey = HolderOfKeys.getDecodingKey(keyNumber: Int(headers["keyNumber"] ?? "") ?? 0)
        return JWTDecoder(algorithm: .rs256(selectedKey, .publicKey))
    }

    public static func handle(request: RouterRequest, response: RouterResponse, completion: @escaping (TypeSafeJWT<C>?, RequestError?) -> Void) {
        // Ideally we'd get this from the router's decoders, but we don't have access to it
        guard let decoder = decoder(headers: request.headers) else {
            return completion(nil, .internalServerError)
        }
        let authorizationHeader = request.headers["Authorization"]
        guard let authorizationHeaderComponents = authorizationHeader?.components(separatedBy: " "),
            authorizationHeaderComponents.count == 2,
            authorizationHeaderComponents[0] == "Bearer",
            let jwt = try? decoder.decode(JWT<C>.self, fromString: authorizationHeaderComponents[1])
        else {
            return completion(nil, .unauthorized)
        }
        completion(TypeSafeJWT(jwt: jwt), nil)
    }
}
