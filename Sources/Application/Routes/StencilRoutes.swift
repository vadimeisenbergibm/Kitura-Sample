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

import KituraStencil
import LoggerAPI
import Stencil

func initializeStencilRoutes(app: App) {
   // add Stencil Template Engine with a extension with a custom tag
    let _extension = Extension()
    // from https://github.com/kylef/Stencil/blob/master/ARCHITECTURE.md#simple-tags
    _extension.registerSimpleTag("custom") { _ in
        return "Hello World"
    }

    let templateEngine = StencilTemplateEngine(extension: _extension)
    app.router.add(templateEngine: templateEngine,
               forFileExtensions: ["html"])

    // the example from https://github.com/kylef/Stencil
    let stencilContext: [String: Any] = [
        "articles": [
            [ "title": "Migrating from OCUnit to XCTest", "author": "Kyle Fuller" ],
            [ "title": "Memory Management with ARC", "author": "Kyle Fuller" ],
        ]
    ]

    app.router.get("/articles") { _, response, next in
        defer {
            next()
        }
        do {
            try response.render("document.stencil", context: stencilContext).end()
        } catch {
            Log.error("Failed to render template \(error)")
        }
    }

    app.router.get("/articles.html") { _, response, next in
        defer {
            next()
        }
        do {
            // we have to specify file extension here since it is not the extension of Stencil
            try response.render("document.html", context: stencilContext).end()
        } catch {
            Log.error("Failed to render template \(error)")
        }
    }

    app.router.get("/articles_subdirectory") { _, response, next in
        defer {
            next()
        }
        do {
            try response.render("subdirectory/documentInSubdirectory.stencil",
                                context: stencilContext).end()
        } catch {
            Log.error("Failed to render template \(error)")
        }
    }

    app.router.get("/articles_include") { _, response, next in
        defer {
            next()
        }
        do {
            try response.render("includingDocument.stencil",
                                context: stencilContext).end()
        } catch {
            Log.error("Failed to render template \(error)")
        }
    }

    app.router.get("/custom_tag_stencil") { _, response, next in
        defer {
            next()
        }
        do {
            try response.render("customTag.stencil", context: [:]).end()
        } catch {
            Log.error("Failed to render template \(error)")
        }
    }
}
