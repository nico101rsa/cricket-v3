"""Flavour data: first-name banks, surname pools, cities and club names.

Ported from Cricket v2 (name_banks.gd, player_names.gd, cities.gd,
city_clubs.gd). Names never enter the sim; they only dress the scorecard.
"""

FIRST_NAMES = {
    "SA": [
        "John", "Jonty", "Quinton", "AB", "Faf", "Dale", "Hansie", "Allan", "Shaun", "Graeme",
        "Vernon", "Wayne", "JP", "Henry", "Garth", "Roger", "Ashwell", "Paul", "Daryll", "Justin",
        "Hashim", "Imran", "Keshav", "Tabraiz", "Rilee", "Reeza", "Yasir", "Omar", "Sulieman", "Aiden",
        "Kagiso", "Temba", "Lungi", "Andile", "Aaron", "Makhaya", "Mfuneko", "Loots", "Thami", "Sibonelo",
    ],
    "AUS": [
        "Steve", "Ricky", "Glenn", "Pat", "Mitchell", "Travis", "Marnus", "Adam", "Brett", "Cameron",
        "Andrew", "Justin", "Damien", "Brad", "Phillip", "Michael", "Stuart", "Tim", "Greg", "Jason",
        "Usman", "Fawad", "Gurinder", "Tanveer", "Aman", "Arjun", "Param", "Nishant", "Jaspreet", "Rohan",
        "Scott", "D'Arcy", "Daniel", "Marcus", "Eddie", "Tyrone", "Will", "Lance", "Nathan", "Josh",
    ],
}

SURNAMES = {
    "SA": [
        "Kgosi", "Naidoo", "Pretorius", "Du Plessis", "Mkhize", "Botha", "Swart",
        "Van Wyk", "Dlamini", "Steyn", "Maharaj", "Nkosi", "Coetzee", "Jacobs", "Sithole",
        "Springer", "Tendul", "Smithers", "Vilas", "Bails", "Stumps", "Yorker",
    ],
    "AUS": [
        "Smith", "Cummins", "Maxwell", "Head", "Carey", "Hazlewood", "Marsh",
        "Green", "Zampa", "Warner", "Starc", "Labuschagne", "Inglis", "Abbott", "Stoinis",
        "Springer", "Dhonner", "Kohlrabi", "Amlaa", "Bails", "Stumps", "Yorker",
    ],
}

CITIES = {
    "SA": [
        "Cape Town", "Johannesburg", "Durban", "Pretoria", "Gqeberha",
        "East London", "Bloemfontein", "Pietermaritzburg", "Centurion",
        "Paarl", "Potchefstroom",
    ],
    "AUS": [
        "Sydney", "Melbourne", "Brisbane", "Perth", "Adelaide",
        "Hobart", "Canberra", "Geelong", "Newcastle", "Darwin",
    ],
}

# Eight club names per city, named for real suburbs and areas.
CLUBS = {
    "Cape Town": ["Newlands CC", "Rondebosch Ramblers", "Sea Point Strollers",
        "Khayelitsha XI", "Claremont Crusaders", "Bo-Kaap Braves",
        "Muizenberg Waves", "Woodstock Wanderers"],
    "Johannesburg": ["Soweto Stars", "Sandton Select", "Alexandra Aces",
        "Randburg Rockets", "Parktown Pilgrims", "Braamfontein XI",
        "Yeoville Yorkers", "Melville CC"],
    "Durban": ["Umhlanga Rocks CC", "Berea Breakers", "Morningside CC",
        "Chatsworth Chargers", "Umlazi XI", "Glenwood Griffins",
        "Phoenix Flames", "Bluff CC"],
    "Pretoria": ["Menlo Park CC", "Hatfield Hurricanes", "Sunnyside Swifts",
        "Waterkloof Warriors", "Arcadia Arrows", "Brooklyn CC",
        "Garsfontein XI", "Silverton Stags"],
    "Gqeberha": ["Summerstrand CC", "Walmer Wanderers", "Newton Park XI",
        "Humewood Harriers", "Motherwell Masters", "Kragga Kamma CC",
        "Richmond Hill Royals", "Charlo Chiefs"],
    "East London": ["Nahoon Nomads", "Vincent CC", "Beacon Bay Blasters",
        "Gonubie Gulls", "Quigney Quicks", "Selborne Strikers",
        "Amalinda XI", "Cambridge Colts"],
    "Bloemfontein": ["Westdene Willows", "Langenhoven Lancers", "Universitas XI",
        "Naval Hill Navigators", "Heidedal Hitters", "Fichardt Park Flyers",
        "Bayswater CC", "Brandwag CC"],
    "Pietermaritzburg": ["Scottsville Scorpions", "Oribi Owls", "Northdale Knights",
        "Athlone CC", "Prestbury Pumas", "Wembley Whites",
        "Hilton XI", "Woodlands Weavers"],
    "Centurion": ["Irene Villagers", "Zwartkops Zebras", "Doringkloof Dukes",
        "Rooihuiskraal CC", "Eldoraigne Eagles", "Hennopspark Herons",
        "Lyttelton XI", "Clubview CC"],
    "Paarl": ["Courtrai CC", "Berg River XI", "Fairyland Flamingos",
        "Mbekweni Mambas", "Huguenot CC", "Klein Drakenstein CC",
        "Paarl East XI", "Denneburg Dassies"],
    "Potchefstroom": ["Die Bult XI", "Mooirivier Mallards", "Baillie Park CC",
        "Grimbeek Giants", "Miederpark Millers", "Van der Hoff CC",
        "Ikageng Invincibles", "Potch Dorp Pipers"],
    "Sydney": ["Manly Seasiders", "Parramatta Pioneers", "Randwick Royals",
        "Balmain Boatmen", "Coogee Crabs", "Penrith Plainsmen",
        "Mosman Mariners", "Bankstown Blues"],
    "Melbourne": ["Fitzroy Foxes", "St Kilda Seagulls", "Carlton Cavaliers",
        "Brunswick Bats", "Richmond Ravens", "Footscray Ferrets",
        "Toorak Toffs", "Coburg CC"],
    "Brisbane": ["Toowong CC", "New Farm Navigators", "Paddington Pelicans",
        "Kangaroo Point XI", "Red Hill Roosters", "Bulimba Barracudas",
        "West End Wombats", "Ascot Anchors"],
    "Perth": ["Fremantle Fishers", "Subiaco Sharks", "Cottesloe Crushers",
        "Scarborough Surfers", "Joondalup Jets", "Leederville Larks",
        "Victoria Park XI", "Midland Mules"],
    "Adelaide": ["Glenelg CC", "Prospect Pacers", "Unley Unicorns",
        "Semaphore Sailors", "Burnside Bouncers", "Henley Beach XI",
        "Mawson Lakes Meteors", "Norwood Nightjars"],
    "Hobart": ["Sandy Bay Skippers", "Battery Point XI", "Glenorchy Gales",
        "Kingston Kestrels", "New Town CC", "Lenah Valley Lynx",
        "Moonah CC", "Bellerive Breakers"],
    "Canberra": ["Manuka CC", "Turner XI", "Dickson Drakes",
        "Belconnen Bullants", "Woden Valley XI", "Gungahlin Gliders",
        "Ainslie Aviators", "Narrabundah CC"],
    "Geelong": ["Barwon Boaters", "Grovedale XI", "Corio Corsairs",
        "Belmont Bluejays", "Highton Hares", "Lara Lorikeets",
        "Torquay Tides", "Ocean Grove Groms"],
    "Newcastle": ["Merewether CC", "Hamilton Hawkers", "Charlestown Cheetahs",
        "Stockton Stingrays", "Wallsend Wallabies", "Kotara Kookaburras",
        "Lambton Lakers", "Adamstown XI"],
    "Darwin": ["Nightcliff Ospreys", "Fannie Bay Frigates", "Parap Pearlers",
        "Stuart Park Stingers", "Casuarina Crocs", "Larrakeyah XI",
        "Palmerston Pythons", "Mindil Beach Marlins"],
}


def country_of_city(city: str) -> str:
    for country, cities in CITIES.items():
        if city in cities:
            return country
    raise KeyError(f"unknown city {city!r}")
