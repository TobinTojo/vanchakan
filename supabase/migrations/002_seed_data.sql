-- Seed data for Vanchakan
-- Questions and crimes

INSERT INTO questions (question_text, question_type, options, category) VALUES
-- School (MC)
('If you suddenly had a free weekend with no responsibilities, what would you most likely do?', 'multiple_choice', '["Binge a TV show or movies", "Go on a spontaneous trip", "Sleep most of the time", "Try a new hobby or project"]', 'School'),
('It is the night before an important exam. What are you most likely doing?', 'multiple_choice', '["Studying seriously and reviewing notes", "Cramming with friends on a video call", "Convincing yourself you already know enough", "Accepting your fate and going to sleep"]', 'School'),
('What is your usual role in a group project?', 'multiple_choice', '["The organizer who keeps everyone on track", "The one who does most of the work", "The creative idea person", "The last-minute contributor"]', 'School'),
('What is the most tempting distraction while studying?', 'multiple_choice', '["Social media", "YouTube or streaming", "Texting friends", "Snacks and wandering around"]', 'School'),
('Finals are finally over. What is your first move?', 'multiple_choice', '["Celebrate with friends", "Sleep for a long time", "Travel or go home", "Start a new show or game"]', 'School'),
('You forgot your homework at home. What do you do?', 'multiple_choice', '["Email the teacher and accept the L", "Ask a friend to share theirs", "Make up an elaborate excuse", "Pretend you did not know it was due"]', 'School'),
('Your professor extends a deadline. You feel:', 'multiple_choice', '["Relieved but still stressed", "Motivated to finish early anyway", "Like you have infinite time now", "Suspicious — what is the catch?"]', 'School'),
('In a lecture, you are most likely:', 'multiple_choice', '["Taking detailed notes", "Half-listening while on your phone", "Asking questions", "Planning what to eat after class"]', 'School'),
-- Work (MC)
('Your boss sends a message at 9 PM. You:', 'multiple_choice', '["Reply immediately to look dedicated", "Read it but reply tomorrow", "Leave it on read until morning", "Panic and overthink the tone"]', 'Work'),
('Team meeting runs over. You:', 'multiple_choice', '["Stay engaged till the end", "Mute and multitask", "Suggest wrapping up politely", "Zone out completely"]', 'Work'),
('Someone takes credit for your idea. You:', 'multiple_choice', '["Call it out directly", "Mention it casually later", "Let it go — not worth the drama", "Plot revenge in your head"]', 'Work'),
('Deadline is tomorrow and you are behind. You:', 'multiple_choice', '["Pull an all-nighter", "Ask for an extension", "Submit something imperfect", "Convince yourself it is fine"]', 'Work'),
('Free lunch at work. You:', 'multiple_choice', '["First in line", "Wait for the good stuff to appear", "Grab extra for later", "Skip it — too many people"]', 'Work'),
-- Entertainment (MC)
('You and your friends are starting a game night. What game are you most likely to suggest?', 'multiple_choice', '["A competitive shooter or battle royale", "A party game where everyone can laugh and yell", "A chill co-op game where everyone works together", "A nostalgic game you played as a kid"]', 'Entertainment'),
('It is movie night with friends. Which type of movie are you most excited to watch?', 'multiple_choice', '["A big action blockbuster", "A horror movie that makes everyone scream", "A dumb comedy everyone can quote later", "A nostalgic childhood favorite"]', 'Entertainment'),
('A new season of your favorite show drops. You:', 'multiple_choice', '["Binge it in one sitting", "Watch one episode per day", "Wait for friends to catch up", "Avoid spoilers like your life depends on it"]', 'Entertainment'),
('At a concert, you are the person who:', 'multiple_choice', '["Sings every word", "Records everything on your phone", "Stays chill in the back", "Gets way too into the mosh pit"]', 'Entertainment'),
('Your friend recommends a show. You:', 'multiple_choice', '["Watch it immediately", "Add it to your endless list", "Pretend you will watch it", "Ask if it is worth the hype first"]', 'Entertainment'),
('Podcast or music while commuting?', 'multiple_choice', '["True crime podcast", "Upbeat playlist", "Silence — need to decompress", "Audiobook"]', 'Entertainment'),
-- Food (MC)
('Late night hunger hits. You reach for:', 'multiple_choice', '["Leftovers from the fridge", "Delivery app", "Cereal straight from the box", "Whatever snack is closest"]', 'Food'),
('At a restaurant, you always:', 'multiple_choice', '["Order the same safe choice", "Try something new", "Ask what everyone else is getting", "Spend 10 minutes deciding"]', 'Food'),
('Someone offers you food they made. You:', 'multiple_choice', '["Accept enthusiastically", "Take a small polite portion", "Claim you are not hungry", "Secretly hope it is good"]', 'Food'),
('Your ideal breakfast is:', 'multiple_choice', '["Full cooked meal", "Coffee only", "Grab and go", "Brunch with friends"]', 'Food'),
-- Friendship (MC)
('Your friend cancels plans last minute. You:', 'multiple_choice', '["No worries, reschedule", "Feel slightly annoyed but hide it", "Make backup plans instantly", "Overthink if they are mad at you"]', 'Friendship'),
('Group chat gets too active. You:', 'multiple_choice', '["Mute notifications", "Reply to everything", "Lurk silently", "Start a side conversation"]', 'Friendship'),
('A friend asks for a favor you do not want to do. You:', 'multiple_choice', '["Say yes anyway", "Make an excuse", "Be honest about it", "Delay responding until they forget"]', 'Friendship'),
('Planning a trip with friends. Your role is:', 'multiple_choice', '["The planner with spreadsheets", "The one who goes with the flow", "The hype person", "The one who books flights last"]', 'Friendship'),
-- Technology (MC)
('Phone battery at 5%. You:', 'multiple_choice', '["Panic and find a charger", "Enter power-saving mode", "Accept your fate", "It is basically always at 5% anyway"]', 'Technology'),
('New phone notification. You check it:', 'multiple_choice', '["Instantly", "Within a few minutes", "When you remember", "Never — 847 unread"]', 'Technology'),
('Your most-used app category is:', 'multiple_choice', '["Social media", "Games", "Productivity", "Video streaming"]', 'Technology'),
-- Personality (MC)
('In a heated debate, you:', 'multiple_choice', '["Argue your point passionately", "Play devil''s advocate", "Try to mediate", "Avoid conflict entirely"]', 'Personality'),
('When making a big decision, you:', 'multiple_choice', '["Make a pro/con list", "Go with your gut", "Ask everyone for advice", "Procrastinate until forced"]', 'Personality'),
('Your friends would describe you as:', 'multiple_choice', '["The funny one", "The reliable one", "The chaotic one", "The quiet observer"]', 'Personality'),
('Under pressure, you:', 'multiple_choice', '["Thrive and get sharper", "Panic internally but perform", "Shut down", "Make jokes to cope"]', 'Personality'),
-- Hypothetical (MC)
('You find $100 on the ground. You:', 'multiple_choice', '["Turn it in", "Keep it — finders keepers", "Donate it", "Treat your friends to food"]', 'Hypothetical'),
('You could have any superpower. You pick:', 'multiple_choice', '["Invisibility", "Flying", "Mind reading", "Time travel"]', 'Hypothetical'),
('Stranded on an island with one item:', 'multiple_choice', '["A knife", "Unlimited wifi", "A friend", "A boat"]', 'Hypothetical'),
('Win the lottery tomorrow. First purchase:', 'multiple_choice', '["Pay off debts", "Travel the world", "Buy something ridiculous", "Invest it all"]', 'Hypothetical');

-- Short answer questions
INSERT INTO questions (question_text, question_type, category) VALUES
('Which celebrity would you most want to meet in real life?', 'short_answer', 'Entertainment'),
('What is a food you could eat every week?', 'short_answer', 'Food'),
('What is your most-used app?', 'short_answer', 'Technology'),
('What fictional character would you trust with your life?', 'short_answer', 'Entertainment'),
('What is your most embarrassing habit?', 'short_answer', 'Embarrassing habits'),
('What is one thing you would buy if money did not matter?', 'short_answer', 'Hypothetical'),
('What is a show you would recommend to everyone?', 'short_answer', 'Entertainment'),
('What is your dream vacation destination?', 'short_answer', 'Travel'),
('What is your most controversial food opinion?', 'short_answer', 'Food'),
('What is a skill you wish you had?', 'short_answer', 'Personality'),
('What is the worst advice you have ever received?', 'short_answer', 'Personality'),
('What song would be your walk-up theme?', 'short_answer', 'Entertainment'),
('What is something you are weirdly good at?', 'short_answer', 'Personality'),
('What is your go-to excuse for being late?', 'short_answer', 'Embarrassing habits'),
('What is the pettiest thing you have ever done?', 'short_answer', 'Embarrassing habits');

-- Crimes
INSERT INTO crimes (crime_text) VALUES
('Someone ate the last slice of pizza and blamed the dog.'),
('Someone changed the group chat name at 3:00 a.m.'),
('Someone secretly watched the next episode without the group.'),
('Someone used another person''s streaming account for six months.'),
('Someone stole fries from everyone''s plate.'),
('Someone sent a risky message from a friend''s unlocked phone.'),
('Someone finished the shared snacks before game night started.'),
('Someone pretended their microphone was broken to avoid answering.'),
('Someone spoiled the ending of a movie.'),
('Someone left the group project until the final night.'),
('Someone removed a friend from the close friends story.'),
('Someone ordered food without asking the rest of the group.'),
('Someone "borrowed" a charger and never returned it.'),
('Someone claimed they were "five minutes away" for forty-five minutes.'),
('Someone reheated fish in the shared microwave.'),
('Someone liked their ex''s photo from three years ago at 2 AM.'),
('Someone finished the shared Netflix profile''s "Continue Watching" list.'),
('Someone screenshot a private conversation and sent it to the group.'),
('Someone ate someone else''s labeled meal from the fridge.'),
('Someone RSVP''d yes to a party and never showed up.'),
('Someone used the last of the toilet paper and said nothing.'),
('Someone told a white lie about having already seen a meme.'),
('Someone took the good seat on the couch and refused to move.'),
('Someone forgot their wallet at dinner and "will Venmo you later."'),
('Someone played their music out loud on public transit.'),
('Someone double-dipped at a party.'),
('Someone left read receipts on and ignored messages for days.'),
('Someone borrowed a hoodie and returned it smelling different.'),
('Someone claimed they were sick to skip plans but posted beach photos.'),
('Someone ate an entire family-size bag of chips alone in one sitting.');
