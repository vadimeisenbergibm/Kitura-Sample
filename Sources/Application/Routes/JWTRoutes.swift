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
	
    // Retrieve the encrption Keys
    let localURL = FileKit.projectFolderURL
    guard let rsaPrivateKey = try? Data(contentsOf: localURL.appendingPathComponent("/JWT/rsa_private_key", isDirectory: false)) else {
        Log.error("Failed to read private key from file")
        return
    }
    guard let rsaPublicKey = try? Data(contentsOf: localURL.appendingPathComponent("/JWT/rsa_public_key", isDirectory: false)) else {
        Log.error("Failed to read public key from file")
        return
    }
    guard let certPrivateKey = try? Data(contentsOf: localURL.appendingPathComponent("/JWT/cert_private_key", isDirectory: false)) else {
        Log.error("Failed to read private key from file")
        return
    }
    guard let certificate = try? Data(contentsOf: localURL.appendingPathComponent("/JWT/certificate", isDirectory: false)) else {
        Log.error("Failed to read public key from file")
        return
    }
    
    // Create the JWT Coders
    let jwtSigners: [String: JWTSigner] = ["0": .rs256(privateKey: rsaPrivateKey), "1": .rs256(privateKey: certPrivateKey)]
    let jwtVerifiers: [String: JWTVerifier] = ["0": .rs256(publicKey: rsaPublicKey), "1": .rs256(certificate: certificate)]
    let jwtEncoder = JWTEncoder(keyIDToSigner: { kid in return jwtSigners[kid]})
    let jwtDecoder = JWTDecoder(keyIDToVerifier: { kid in return jwtVerifiers[kid]})
    
    // Set the JWT Coders on the route
    app.router.encoders[MediaType(type: .application, subType: "jwt")] = { return jwtEncoder }
    app.router.decoders[MediaType(type: .application, subType: "jwt")] = { return jwtDecoder }
    
    // Register the app routes
	app.router.post("/jwt/create_token", handler: app.postFormHandler)
    app.router.get("/jwt/protected", handler: app.protectedHandler)
    app.router.post("/jwtcoder", handler: app.jwtCoder)
}

extension App {
    
    func postFormHandler(claims: TokenDetails, respondWith: (JWT<TokenDetails>?, RequestError?) -> Void) {
        let datedClaim = TokenDetails(iat: Date(), exp: Date(timeIntervalSinceNow: 3600), name: claims.name, favourite: claims.favourite)
        let jwt = JWT(header: Header(kid: "0"), claims: datedClaim)
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
    static var decoder: JWTDecoder? {
        let localURL = FileKit.projectFolderURL
        guard let publicKey = try? Data(contentsOf: localURL.appendingPathComponent("/JWT/rsa_public_key", isDirectory: false)) else {
            Log.error("Failed to read public key from file")
            return nil
        }
        return JWTDecoder(jwtVerifier: .rs256(publicKey: publicKey))
    }
    
    public static func handle(request: RouterRequest, response: RouterResponse, completion: @escaping (TypeSafeJWT<C>?, RequestError?) -> Void) {
        guard let decoder = decoder else {
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
