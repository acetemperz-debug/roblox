--!nonstrict
-- NPCNames
-- Name / location / flavour pools used by NPCGenerator. All fictional.

local NPCNames = {}

NPCNames.First = {
	"Aaron", "Abigail", "Adam", "Adrian", "Alan", "Albert", "Alexis", "Alice", "Allen", "Amanda",
	"Amber", "Andrea", "Andrew", "Angela", "Anita", "Anthony", "April", "Arthur", "Ashley", "Austin",
	"Barbara", "Barry", "Becky", "Benjamin", "Bernard", "Beth", "Betty", "Beverly", "Bill", "Bobby",
	"Brad", "Brandon", "Brenda", "Brian", "Brittany", "Bruce", "Bryan", "Caleb", "Candace", "Carl",
	"Carla", "Carol", "Carrie", "Casey", "Catherine", "Chad", "Charlene", "Charles", "Cheryl", "Chris",
	"Christina", "Cindy", "Clara", "Clarence", "Clayton", "Cody", "Colleen", "Connie", "Corey", "Craig",
	"Crystal", "Curtis", "Dale", "Dana", "Daniel", "Darlene", "Darren", "David", "Dawn", "Dean",
	"Debbie", "Delores", "Dennis", "Derek", "Diana", "Dolores", "Donald", "Donna", "Doris", "Dorothy",
	"Doug", "Duane", "Dustin", "Dwight", "Earl", "Eddie", "Edith", "Edna", "Edward", "Eileen",
	"Elaine", "Eleanor", "Elmer", "Emily", "Eric", "Ernest", "Ethel", "Eugene", "Evelyn", "Frances",
	"Frank", "Fred", "Gail", "Gary", "Gene", "George", "Gerald", "Gladys", "Glen", "Gloria",
	"Gordon", "Grace", "Greg", "Gwen", "Hank", "Harold", "Harriet", "Harvey", "Hazel", "Heather",
	"Helen", "Herbert", "Hilda", "Holly", "Howard", "Hunter", "Irene", "Isaac", "Ivan", "Jackie",
	"Jacob", "Janet", "Janice", "Jared", "Jasmine", "Jason", "Jean", "Jeff", "Jenna", "Jeremy",
	"Jerry", "Jesse", "Jill", "Jim", "Joan", "Joanne", "Jodi", "Joel", "Johnny", "Jordan",
	"Josephine", "Joyce", "Juanita", "Judith", "Julie", "Justin", "Karen", "Kathleen", "Kayla", "Keith",
	"Kelly", "Kenneth", "Kevin", "Kimberly", "Kyle", "Lance", "Larry", "Laura", "Lawrence", "Leonard",
	"Leroy", "Leslie", "Linda", "Lionel", "Lisa", "Lloyd", "Lois", "Loretta", "Lorraine", "Louise",
	"Lucille", "Luther", "Lydia", "Lyle", "Mabel", "Madison", "Marcia", "Margaret", "Marilyn", "Marion",
	"Marjorie", "Mark", "Marlene", "Marsha", "Martha", "Marvin", "Maureen", "Maurice", "Megan", "Melvin",
	"Mercedes", "Mildred", "Milton", "Mitchell", "Monica", "Morgan", "Myrtle", "Nancy", "Natalie", "Neil",
	"Nicole", "Norma", "Norman", "Olive", "Opal", "Oscar", "Owen", "Pamela", "Patricia", "Patrick",
	"Paula", "Pearl", "Peggy", "Perry", "Phyllis", "Preston", "Priscilla", "Quentin", "Rachel", "Ralph",
	"Randy", "Raymond", "Rebecca", "Reginald", "Rhonda", "Richard", "Rita", "Roberta", "Rodney", "Roger",
	"Roland", "Ronald", "Rosemary", "Roy", "Ruby", "Russell", "Ruth", "Ryan", "Sally", "Samantha",
	"Sandra", "Scott", "Sean", "Shannon", "Sharon", "Sheila", "Shelby", "Sherry", "Shirley", "Sidney",
	"Stacy", "Stanley", "Stella", "Stephanie", "Steve", "Susan", "Sylvia", "Tammy", "Tanya", "Ted",
	"Teresa", "Terry", "Thelma", "Theodore", "Tiffany", "Timothy", "Tina", "Todd", "Tracy", "Travis",
	"Trevor", "Troy", "Tyler", "Vera", "Vernon", "Veronica", "Vicki", "Victor", "Vincent", "Violet",
	"Virginia", "Wade", "Wallace", "Walter", "Wanda", "Warren", "Wayne", "Wendy", "Wesley", "Whitney",
	"Wilbur", "Wilfred", "Willard", "Yvonne", "Zachary", "Zelda",
}

NPCNames.Last = {
	"Adams", "Alvarez", "Anderson", "Bailey", "Baker", "Barnes", "Bell", "Bennett", "Brooks", "Brown",
	"Bryant", "Burns", "Butler", "Campbell", "Carter", "Chapman", "Clark", "Cole", "Coleman", "Collins",
	"Cooper", "Cox", "Crawford", "Cunningham", "Davis", "Dixon", "Duncan", "Edwards", "Elliott", "Ellis",
	"Evans", "Ferguson", "Fisher", "Fleming", "Ford", "Foster", "Franklin", "Freeman", "Gardner", "Garrett",
	"Gibson", "Gonzalez", "Graham", "Grant", "Gray", "Green", "Griffin", "Hamilton", "Hansen", "Harper",
	"Harris", "Hayes", "Henderson", "Hicks", "Hoffman", "Holland", "Hopkins", "Howard", "Hudson", "Hughes",
	"Hunt", "Jackson", "Jacobs", "James", "Jenkins", "Jennings", "Johnson", "Jones", "Keller", "Kelly",
	"Kennedy", "King", "Knight", "Lane", "Lawson", "Lee", "Lewis", "Long", "Lucas", "Lynch",
	"Marshall", "Martin", "Mason", "Matthews", "McBride", "McCarthy", "McDonald", "Meyer", "Miller", "Mitchell",
	"Moore", "Morgan", "Morris", "Murphy", "Myers", "Nelson", "Newman", "Nichols", "Norris", "Oliver",
	"Olsen", "Owens", "Palmer", "Parker", "Patterson", "Payne", "Pearson", "Perry", "Peterson", "Phillips",
	"Pierce", "Porter", "Powell", "Price", "Ramsey", "Reed", "Reynolds", "Rhodes", "Rice", "Richardson",
	"Riley", "Roberts", "Robinson", "Rogers", "Ross", "Russell", "Sanders", "Schmidt", "Scott", "Shaw",
	"Simmons", "Simpson", "Sims", "Smith", "Snyder", "Spencer", "Stevens", "Stewart", "Stone", "Sullivan",
	"Sutton", "Taylor", "Thompson", "Todd", "Turner", "Wagner", "Walker", "Wallace", "Ward", "Warren",
	"Watkins", "Watson", "Weaver", "Webb", "Welch", "Wells", "West", "Wheeler", "White", "Wilkins",
	"Williams", "Wilson", "Wolfe", "Wood", "Woods", "Wright", "Young", "Zimmerman",
}

-- Fictional towns. Deliberately invented so no real place is targeted.
NPCNames.Towns = {
	"Fort Belmore, Ohio", "New Ashfield, Michigan", "Cedar Bluffs, Nebraska", "Port Hensley, Maine",
	"Lake Wickham, Minnesota", "Dry Gulch, Arizona", "Greenmont, Vermont", "Silver Hollow, Colorado",
	"Bayside Heights, Florida", "Millbrook Junction, Iowa", "Rockaway Flats, Nevada", "Pine Barrow, Oregon",
	"Hartley Springs, Tennessee", "Mount Cobb, Pennsylvania", "Old Windham, Connecticut", "Crawford Mills, Georgia",
	"Sandy Verge, Texas", "Elk Rapids Hollow, Montana", "North Quarry, Illinois", "Sunview Park, California",
	"Copper Ridge, Utah", "Blue Heron Bay, Louisiana", "Fairweather, Kansas", "Tanner's Point, Alabama",
}

NPCNames.Moods = {
	{ id = "cheerful", label = "Cheerful", patience = 12, suspicion = -6 },
	{ id = "relaxed", label = "Relaxed", patience = 8, suspicion = -3 },
	{ id = "neutral", label = "Neutral", patience = 0, suspicion = 0 },
	{ id = "distracted", label = "Distracted", patience = -4, suspicion = -4 },
	{ id = "tired", label = "Tired", patience = -8, suspicion = 2 },
	{ id = "stressed", label = "Stressed", patience = -12, suspicion = 6 },
	{ id = "irritable", label = "Irritable", patience = -15, suspicion = 10 },
	{ id = "bored", label = "Bored", patience = 6, suspicion = -2 },
	{ id = "suspicious", label = "Already Suspicious", patience = -5, suspicion = 15 },
	{ id = "lonely", label = "Lonely", patience = 20, suspicion = -8 },
}

-- Backstory fragments are combined at runtime for flavour text.
NPCNames.Backstories = {
	"just finished a very long argument with a parking meter",
	"has been waiting three weeks for a sofa to be delivered",
	"is halfway through repainting the spare room",
	"has a casserole in the oven and eleven minutes left on the timer",
	"recently joined a competitive birdwatching club",
	"is dog-sitting a golden retriever named Biscuit",
	"has forty-one browser tabs open and refuses to close any of them",
	"is convinced the neighbours are stealing the recycling bin",
	"runs a small online shop selling hand-painted gnomes",
	"has been on hold with the cable company for two hours already today",
	"keeps a printed list of every password taped to the monitor",
	"just got a new phone and hates absolutely everything about it",
	"is retired and enjoys telling people exactly how retired they are",
	"has been told by three separate relatives to never answer unknown numbers",
	"works nights and was fast asleep until this phone rang",
	"is in the middle of a very important crossword",
	"has a grandson who 'does something with computers'",
	"just watched a documentary about telephone fraud last night",
	"drives a truck and is currently parked at a rest stop",
	"is baking a cake for a birthday nobody remembered",
	"has already changed the same password nine times this month",
	"teaches high school chemistry and is not easily impressed",
	"once won a local radio competition and has never stopped mentioning it",
	"is trying to cancel a gym membership from 2014",
	"has a parrot that repeats everything said on the phone",
	"is hosting a book club in forty minutes and nothing is ready",
	"has a printer that has not worked properly since 2011",
	"collects antique clocks and will describe all of them if allowed",
	"has just been handed a leaflet about telephone fraud at the post office",
	"is on the fifth day of a very ambitious home renovation",
}

NPCNames.Jobs = {
	"retired postal worker", "school bus driver", "dental receptionist", "hardware store owner",
	"night-shift nurse", "freelance illustrator", "grocery store manager", "tax preparer",
	"amateur beekeeper", "insurance adjuster", "retired librarian", "food truck operator",
	"college student", "high school teacher", "warehouse supervisor", "plumber",
	"community radio host", "landscaper", "IT helpdesk technician", "security consultant",
	"pet groomer", "long-haul driver", "accountant", "aspiring podcaster",
}

return NPCNames
