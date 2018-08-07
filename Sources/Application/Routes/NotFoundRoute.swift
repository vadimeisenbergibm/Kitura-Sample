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

func initializeNotFoundRoute(app: App) {
    // A custom Not found handler
    app.router.all { request, response, next in
        if  response.statusCode == .unknown  {
            // Remove this wrapping if statement, if you want to handle requests to / as well
            let path = request.urlURL.path
            if  path != "/" && path != ""  {
                try response.status(.notFound).send("Route not found in Sample application!").end()
            }
        }
        next()
    }
}
