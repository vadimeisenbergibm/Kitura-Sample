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

import Foundation
import Kitura
import LoggerAPI

func initializeStaticFileServers(app: App) {
    app.router.all("/static", middleware: StaticFileServer())
    app.router.all("/chat", middleware: StaticFileServer(path: "./chat"))
    app.router.all("/", middleware: StaticFileServer(path: "./Views"))
    app.router.get("/") { request, response, next in
        response.headers["Content-Type"] = "text/html; charset=utf-8"
        do {
            try response.render("home.html", context: [String: Any]()).end()
        } catch {
            Log.error("Failed to render template \(error)")
        }
        
    }
}
