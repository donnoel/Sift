// PATH: SiftTests/TestSupport/Fixtures.swift
import Foundation

enum Fixtures {
    private static func data(_ json: String) -> Data { Data(json.utf8) }

    // Search results for "Interstellar" where the correct match has id 157336 and release_date in 2014.
    static let searchInterstellar: Data = data("""
    {
      "results": [
        {
          "id": 157336,
          "title": "Interstellar",
          "release_date": "2014-11-05",
          "poster_path": "/nBNZadXqJSdt05SHLqgT0HuC5Gm.jpg",
          "overview": "A team travels through a wormhole.",
          "vote_average": 8.3
        },
        {
          "id": 123,
          "title": "Interstaller",
          "release_date": "2015-01-01",
          "poster_path": null,
          "overview": "Typos happen.",
          "vote_average": 5.0
        }
      ]
    }
    """)

    // Details for Interstellar (id 157336)
    static let detailsInterstellar: Data = data("""
    {
      "id": 157336,
      "title": "Interstellar",
      "release_date": "2014-11-05",
      "poster_path": "/nBNZadXqJSdt05SHLqgT0HuC5Gm.jpg",
      "overview": "Explorers undertake a mission.",
      "vote_average": 8.6,
      "genres": [{"name":"Science Fiction"}],
      "runtime": 169
    }
    """)

    // TMDB images configuration: includes w500 and secure base url
    static let imagesConfig: Data = data("""
    {
      "images": {
        "base_url": "http://image.tmdb.org/t/p/",
        "secure_base_url": "https://image.tmdb.org/t/p/",
        "poster_sizes": ["w92", "w154", "w342", "w500", "w780", "original"]
      }
    }
    """)

    // Optional extra fixtures used in other tests you referenced
    static let searchAlienVariants: Data = data("""
    {
      "results": [
        {
          "id": 1,
          "title": "Alien",
          "release_date": "1979-05-25",
          "poster_path": "/poster1.jpg",
          "overview": "Classic sci-fi horror.",
          "vote_average": 8.4
        },
        {
          "id": 2,
          "title": "Alien",
          "release_date": "2014-01-01",
          "poster_path": "/poster2.jpg",
          "overview": "A modern reboot.",
          "vote_average": 9.0
        }
      ]
    }
    """)

    static let detailsAlien1979: Data = data("""
    {
      "id": 1,
      "title": "Alien",
      "release_date": "1979-05-25",
      "poster_path": "/poster1.jpg",
      "overview": "The crew of the Nostromo encounters a deadly alien lifeform.",
      "vote_average": 8.4,
      "genres": [{"name":"Science Fiction"}]
    }
    """)
}
