// Flavour data: first names, surnames, cities and club names (from Cricket v2).
(function (root, factory) {
  const mod = factory(root.Cricket || (root.Cricket = {}));
  if (typeof module !== 'undefined' && module.exports) module.exports = mod;
})(globalThis, function (Cricket) {
  const FIRST_NAMES = {
    SA: ['John', 'Jonty', 'Quinton', 'AB', 'Faf', 'Dale', 'Hansie', 'Allan', 'Shaun', 'Graeme',
      'Vernon', 'Wayne', 'JP', 'Henry', 'Garth', 'Roger', 'Ashwell', 'Paul', 'Daryll', 'Justin',
      'Hashim', 'Imran', 'Keshav', 'Tabraiz', 'Rilee', 'Reeza', 'Yasir', 'Omar', 'Sulieman', 'Aiden',
      'Kagiso', 'Temba', 'Lungi', 'Andile', 'Aaron', 'Makhaya', 'Mfuneko', 'Loots', 'Thami', 'Sibonelo',
      'Dean', 'Marco', 'Ryan', 'Heinrich', 'Wiaan', 'Gerald', 'Anrich', 'Tristan', 'Kyle', 'Dewald'],
    AUS: ['Steve', 'Ricky', 'Glenn', 'Pat', 'Mitchell', 'Travis', 'Marnus', 'Adam', 'Brett', 'Cameron',
      'Andrew', 'Justin', 'Damien', 'Brad', 'Phillip', 'Michael', 'Stuart', 'Tim', 'Greg', 'Jason',
      'Usman', 'Fawad', 'Gurinder', 'Tanveer', 'Aman', 'Arjun', 'Param', 'Nishant', 'Jaspreet', 'Rohan',
      'Scott', "D'Arcy", 'Daniel', 'Marcus', 'Eddie', 'Tyrone', 'Will', 'Lance', 'Nathan', 'Josh',
      'Xavier', 'Sean', 'Matt', 'Ben', 'Jhye', 'Todd', 'Ashton', 'Aaron', 'Kane', 'Jake'],
  };
  const SURNAMES = {
    SA: ['Kgosi', 'Naidoo', 'Pretorius', 'Du Plessis', 'Mkhize', 'Botha', 'Swart', 'Van Wyk', 'Dlamini', 'Steyn',
      'Maharaj', 'Nkosi', 'Coetzee', 'Jacobs', 'Sithole', 'Springer', 'Tendul', 'Smithers', 'Vilas', 'Bails',
      'Stumps', 'Yorker', 'Zondo', 'Pillay', 'Fourie', 'Mahlangu', 'Van Niekerk', 'Ngidi', 'Petersen', 'Malan',
      'Erasmus', 'Kruger', 'Molefe', 'Adams', 'Hendricks', 'Rabada', 'Bavuma', 'Linde', 'Nortje', 'Klaasen'],
    AUS: ['Smith', 'Cummins', 'Maxwell', 'Head', 'Carey', 'Hazlewood', 'Marsh', 'Green', 'Zampa', 'Warner',
      'Starc', 'Labuschagne', 'Inglis', 'Abbott', 'Stoinis', 'Springer', 'Dhonner', 'Kohlrabi', 'Amlaa', 'Bails',
      'Stumps', 'Yorker', 'Khawaja', 'Hardie', 'Neser', 'Richardson', 'Agar', 'Short', 'Fraser-McGurk', 'Bartlett',
      'Sangha', 'Philippe', 'McDermott', 'Wade', 'Turner', 'Ellis', 'Dwarshuis', 'Behrendorff', 'Sams', 'Swepson'],
  };
  const CITIES = {
    SA: ['Cape Town', 'Johannesburg', 'Durban', 'Pretoria', 'Gqeberha', 'East London', 'Bloemfontein', 'Pietermaritzburg', 'Centurion', 'Paarl', 'Potchefstroom'],
    AUS: ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide', 'Hobart', 'Canberra', 'Geelong', 'Newcastle', 'Darwin'],
  };
  const CLUBS = {
    'Pretoria': ['Menlo Park CC', 'Hatfield Hurricanes', 'Sunnyside Swifts', 'Waterkloof Warriors', 'Arcadia Arrows', 'Brooklyn CC', 'Garsfontein XI', 'Silverton Stags'],
    'Sydney': ['Manly Seasiders', 'Parramatta Pioneers', 'Randwick Royals', 'Balmain Boatmen', 'Coogee Crabs', 'Penrith Plainsmen', 'Mosman Mariners', 'Bankstown Blues'],
    'Cape Town': ['Newlands CC', 'Rondebosch Ramblers', 'Sea Point Strollers', 'Khayelitsha XI', 'Claremont Crusaders', 'Bo-Kaap Braves', 'Muizenberg Waves', 'Woodstock Wanderers'],
    'Johannesburg': ['Soweto Stars', 'Sandton Select', 'Alexandra Aces', 'Randburg Rockets', 'Parktown Pilgrims', 'Braamfontein XI', 'Yeoville Yorkers', 'Melville CC'],
    'Durban': ['Umhlanga Rocks CC', 'Berea Breakers', 'Morningside CC', 'Chatsworth Chargers', 'Umlazi XI', 'Glenwood Griffins', 'Phoenix Flames', 'Bluff CC'],
    'Melbourne': ['Fitzroy Foxes', 'St Kilda Seagulls', 'Carlton Cavaliers', 'Brunswick Bats', 'Richmond Ravens', 'Footscray Ferrets', 'Toorak Toffs', 'Coburg CC'],
    'Brisbane': ['Toowong CC', 'New Farm Navigators', 'Paddington Pelicans', 'Kangaroo Point XI', 'Red Hill Roosters', 'Bulimba Barracudas', 'West End Wombats', 'Ascot Anchors'],
    'Perth': ['Fremantle Fishers', 'Subiaco Sharks', 'Cottesloe Crushers', 'Scarborough Surfers', 'Joondalup Jets', 'Leederville Larks', 'Victoria Park XI', 'Midland Mules'],
  };
  function countryOfCity(city) {
    for (const [country, cities] of Object.entries(CITIES)) if (cities.includes(city)) return country;
    throw new Error(`unknown city ${city}`);
  }
  return (Cricket.names = { FIRST_NAMES, SURNAMES, CITIES, CLUBS, countryOfCity });
});
