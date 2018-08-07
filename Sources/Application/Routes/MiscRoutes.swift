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

import Kitura
import LoggerAPI

func initializeMiscRoutes(app: App) {
    
    // This route executes the echo middleware
    app.router.all(middleware: BasicAuthMiddleware())
    
    // Redirection example
    app.router.get("/redir") { _, response, next in
        try response.redirect("http://www.ibm.com/us-en/")
        next()
    }

    // Reading parameters
    // Accepts user as a parameter
    app.router.get("/users/:user") { request, response, next in
        response.headers["Content-Type"] = "text/html"
        let p1 = request.parameters["user"] ?? "(nil)"
        try response.send(
            "<!DOCTYPE html><html><body>" +
                "<b>User:</b> \(p1)" +
            "</body></html>\n\n").end()
    }

    app.router.get("/user/:id", allowPartialMatch: false, middleware: CustomParameterMiddleware())
    app.router.get("/user/:id", handler: customParameterHandler)
}

/**
 * RouterMiddleware can be used for intercepting requests and handling custom behavior
 * such as authentication and other routing
 */
class BasicAuthMiddleware: RouterMiddleware {
    func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        let authString = request.headers["Authorization"]
        Log.info("Authorization: \(String(describing: authString))")
        // Check authorization string in database to approve the request if fail
        // response.error = NSError(domain: "AuthFailure", code: 1, userInfo: [:])
        next()
    }
}

let customParameterHandler: RouterHandler = { request, response, next in
    let id = request.parameters["id"] ?? "unknown"
    response.send("\(id)|").status(.OK)
    next()
}

class CustomParameterMiddleware: RouterMiddleware {
    func handle(request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) {
        do {
            try customParameterHandler(request, response, next)
        } catch {
            Log.error("customParameterHandler returned error: \(error)")
        }
        
    }
}
