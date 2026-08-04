-- Expanded Vanchakan question bank (80 MC + 40 short answer)

ALTER TABLE questions ADD COLUMN IF NOT EXISTS external_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS questions_external_id_unique ON questions (external_id);

UPDATE questions SET is_active = false;

INSERT INTO questions (external_id, question_text, question_type, options, category, is_active)
VALUES
('v2-university-001', 'It is the night before an important exam. What are you most likely doing?', 'multiple_choice', '["Studying seriously and reviewing everything","Cramming while on a call with friends","Convincing myself that I already know enough","Accepting my fate and going to sleep"]'::jsonb, 'university', true),
('v2-university-002', 'What is your usual role in a group project?', 'multiple_choice', '["The organizer who keeps everyone on track","The person who ends up doing most of the work","The creative person who comes up with ideas","The person who becomes active near the deadline"]'::jsonb, 'university', true),
('v2-university-003', 'Your professor moves the deadline back by one week. What do you do?', 'multiple_choice', '["Finish the assignment early anyway","Tell myself I will start tomorrow","Completely forget about it until the new deadline","Use the extra time to make it perfect"]'::jsonb, 'university', true),
('v2-university-004', 'You have an 8:30 a.m. class. What usually happens?', 'multiple_choice', '["I arrive early and prepared","I arrive exactly on time","I walk in a few minutes late","I watch the recording later"]'::jsonb, 'university', true),
('v2-university-005', 'What is your go-to study location?', 'multiple_choice', '["The quietest part of the library","A busy café","My bedroom","Wherever my friends are studying"]'::jsonb, 'university', true),
('v2-university-006', 'During a long lecture, what are you most likely doing?', 'multiple_choice', '["Taking detailed notes","Checking social media","Online shopping or browsing random websites","Fighting to stay awake"]'::jsonb, 'university', true),
('v2-university-007', 'Your professor says the exam will be based on the textbook. What do you do?', 'multiple_choice', '["Read every assigned chapter","Find an online summary","Ask someone else what is important","Hope the lecture slides are enough"]'::jsonb, 'university', true),
('v2-university-008', 'You receive a lower grade than expected. What is your first reaction?', 'multiple_choice', '["Review my mistakes and improve","Calculate whether I can still pass the course","Complain about the grading to my friends","Avoid checking the feedback"]'::jsonb, 'university', true),
('v2-university-009', 'How do you normally choose your university courses?', 'multiple_choice', '["Based on career value","Based on how interesting they sound","Based on which professor is teaching","Based on which course seems easiest"]'::jsonb, 'university', true),
('v2-university-010', 'Your group project is due tonight, but one member has disappeared. What do you do?', 'multiple_choice', '["Complete their section myself","Message them repeatedly","Tell the professor immediately","Submit the project without their part"]'::jsonb, 'university', true),
('v2-university-011', 'What is your relationship with your school email?', 'multiple_choice', '["I check it several times every day","I check it once a day","I only check it when I expect something","Important emails regularly surprise me"]'::jsonb, 'university', true),
('v2-university-012', 'You have a three-hour break between classes. What do you do?', 'multiple_choice', '["Study or finish assignments","Get food with friends","Go home if possible","Find somewhere to nap"]'::jsonb, 'university', true),
('v2-university-013', 'You realize you have an assignment due at midnight. It is currently 9:00 p.m. What happens?', 'multiple_choice', '["I create a plan and work efficiently","I panic but somehow finish it","I ask my friends what they did","I accept the late penalty"]'::jsonb, 'university', true),
('v2-university-014', 'What kind of student are you during class discussions?', 'multiple_choice', '["I participate regularly","I speak only when I have a strong answer","I avoid eye contact with the professor","I hope someone else answers first"]'::jsonb, 'university', true),
('v2-university-015', 'Your class has a presentation worth 30%. How do you feel?', 'multiple_choice', '["Excited because I like presenting","Nervous, but I will prepare carefully","Fine as long as it is a group presentation","Ready to drop the course"]'::jsonb, 'university', true),
('v2-social-001', 'Your friends are making plans in the group chat. What role do you take?', 'multiple_choice', '["I organize the entire plan","I agree with whatever everyone chooses","I suggest ideas but avoid organizing","I respond after the plan is already made"]'::jsonb, 'social', true),
('v2-social-002', 'You arrive at a party where you barely know anyone. What do you do?', 'multiple_choice', '["Introduce myself to new people","Stay close to the person I came with","Find the food and snacks","Consider leaving early"]'::jsonb, 'social', true),
('v2-social-003', 'Your friend says, "I have something to tell you, but you cannot tell anyone." What do you do?', 'multiple_choice', '["Keep it completely private","Tell only my closest friend","Ask for permission before telling someone","Accidentally reveal it later"]'::jsonb, 'social', true),
('v2-social-004', 'Someone cancels plans at the last minute. How do you feel?', 'multiple_choice', '["Disappointed because I was looking forward to it","Relieved because I wanted to stay home","Annoyed because I already got ready","Fine because we can reschedule"]'::jsonb, 'social', true),
('v2-social-005', 'What are you usually like in a group chat?', 'multiple_choice', '["I send most of the messages","I react to messages but rarely type","I send memes and disappear","I read everything without responding"]'::jsonb, 'social', true),
('v2-social-006', 'Your friend posts an embarrassing photo of you. What do you do?', 'multiple_choice', '["Laugh and repost it","Ask them to delete it","Post an embarrassing photo of them","Pretend I did not see it"]'::jsonb, 'social', true),
('v2-social-007', 'Your friend is clearly making a bad decision. What do you do?', 'multiple_choice', '["Tell them honestly","Support them but share my concerns","Stay out of it","Watch the situation unfold"]'::jsonb, 'social', true),
('v2-social-008', 'Your friends cannot decide where to eat. What do you do?', 'multiple_choice', '["Choose a restaurant for everyone","Suggest several options","Say I am fine with anything","Reject every suggestion without offering one"]'::jsonb, 'social', true),
('v2-social-009', 'You see someone you know in public, but they have not noticed you. What do you do?', 'multiple_choice', '["Walk over and say hello","Wait to see if they notice me","Send them a message instead","Quietly avoid being seen"]'::jsonb, 'social', true),
('v2-social-010', 'What type of friend are you during a crisis?', 'multiple_choice', '["The problem solver","The emotional support person","The person who uses humour to help","The person who needs someone to explain what is happening"]'::jsonb, 'social', true),
('v2-technology-001', 'What is the first thing you usually do after waking up?', 'multiple_choice', '["Check my notifications","Go back to sleep","Get out of bed immediately","Scroll through social media"]'::jsonb, 'technology', true),
('v2-technology-002', 'Your phone battery is at 5% and you are away from home. What do you do?', 'multiple_choice', '["Turn on low-power mode immediately","Ask everyone for a charger","Continue using it normally","Accept that my phone is about to die"]'::jsonb, 'technology', true),
('v2-technology-003', 'You accidentally like an old post while looking through someone''s profile. What do you do?', 'multiple_choice', '["Unlike it immediately","Leave it and act confident","Block the person temporarily","Close the app and panic"]'::jsonb, 'technology', true),
('v2-technology-004', 'Which message causes the most stress?', 'multiple_choice', '["\"Can we talk?\"","\"Your assignment has been graded.\"","\"Are you awake?\"","\"I need a favour.\""]'::jsonb, 'technology', true),
('v2-technology-005', 'How many browser tabs do you normally have open?', 'multiple_choice', '["Fewer than five","Between five and fifteen","More than fifteen","So many that I cannot see the titles"]'::jsonb, 'technology', true),
('v2-technology-006', 'Someone sends you a five-minute voice message. What do you do?', 'multiple_choice', '["Listen to the entire thing immediately","Play it at double speed","Ask them to summarize it","Forget to listen to it"]'::jsonb, 'technology', true),
('v2-technology-007', 'What are you most likely to send your friends?', 'multiple_choice', '["Memes","Short videos","Voice messages","Screenshots of conversations"]'::jsonb, 'technology', true),
('v2-technology-008', 'How quickly do you normally respond to messages?', 'multiple_choice', '["Almost immediately","Within a few hours","Whenever I have enough social energy","I respond mentally and forget to type it"]'::jsonb, 'technology', true),
('v2-technology-009', 'Your favourite app stops working for an entire day. What do you do?', 'multiple_choice', '["Find another app","Keep checking whether it is fixed","Become strangely productive","Complain about it to everyone"]'::jsonb, 'technology', true),
('v2-technology-010', 'Your screen-time report appears. How do you react?', 'multiple_choice', '["I am proud of my self-control","I am slightly concerned","I immediately close it","I blame one specific app"]'::jsonb, 'technology', true),
('v2-entertainment-001', 'You have a free night with no responsibilities. What do you do?', 'multiple_choice', '["Binge a show or movies","Play video games","Go out with friends","Sleep for most of the night"]'::jsonb, 'entertainment', true),
('v2-entertainment-002', 'Your friends are choosing a game for game night. What do you suggest?', 'multiple_choice', '["A competitive game","A loud party game","A cooperative game","A nostalgic game from childhood"]'::jsonb, 'entertainment', true),
('v2-entertainment-003', 'It is movie night. Which movie are you most excited to watch?', 'multiple_choice', '["A major action movie","A horror movie","A comedy everyone can quote","A nostalgic childhood movie"]'::jsonb, 'entertainment', true),
('v2-entertainment-004', 'Someone spoils the ending of a show you are watching. What do you do?', 'multiple_choice', '["Get genuinely angry","Pretend it does not bother me","Avoid that person for the rest of the day","Forget the spoiler before reaching the ending"]'::jsonb, 'entertainment', true),
('v2-entertainment-005', 'You start a new television series. What usually happens?', 'multiple_choice', '["I watch one episode at a time","I finish the season in a few days","I stop halfway through","I watch recaps instead"]'::jsonb, 'entertainment', true),
('v2-entertainment-006', 'What type of video are you most likely to watch at 2:00 a.m.?', 'multiple_choice', '["A long video essay","Funny clips","A conspiracy theory","A tutorial for something I will never try"]'::jsonb, 'entertainment', true),
('v2-entertainment-007', 'You lose a competitive game because of your teammate. What do you do?', 'multiple_choice', '["Stay calm and move on","Blame them privately","Blame them publicly","Say the game is not that serious"]'::jsonb, 'entertainment', true),
('v2-entertainment-008', 'Your favourite artist announces a concert nearby. What do you do?', 'multiple_choice', '["Buy tickets immediately","Wait to see who else is going","Check the price before becoming excited","Watch concert clips online instead"]'::jsonb, 'entertainment', true),
('v2-entertainment-009', 'What matters most when choosing a new show?', 'multiple_choice', '["The story","The characters","Recommendations from friends","Short clips I saw online"]'::jsonb, 'entertainment', true),
('v2-entertainment-010', 'Which describes your music habits best?', 'multiple_choice', '["I carefully build playlists","I listen to the same songs repeatedly","I let an algorithm choose everything","I constantly search for new music"]'::jsonb, 'entertainment', true),
('v2-food-001', 'You are trying to save money, but your friends suggest ordering food. What do you do?', 'multiple_choice', '["Cook something at home","Order the cheapest option","Spend the money and regret it later","Say I am not hungry, then eat their food"]'::jsonb, 'food', true),
('v2-food-002', 'What happens when you go grocery shopping while hungry?', 'multiple_choice', '["I follow my list carefully","I buy too many snacks","I buy ingredients for meals I never make","I forget the main thing I needed"]'::jsonb, 'food', true),
('v2-food-003', 'Someone asks where you want to eat. What do you say?', 'multiple_choice', '["I choose immediately","I provide several options","\"I do not care\"","\"Anywhere except that one place\""]'::jsonb, 'food', true),
('v2-food-004', 'Your friend asks for one bite of your food. What do you do?', 'multiple_choice', '["Share without hesitation","Give them a small bite","Say no","Offer to buy them their own food"]'::jsonb, 'food', true),
('v2-food-005', 'You receive unexpected money. What is your first move?', 'multiple_choice', '["Save it","Buy something I have wanted","Spend it on food or entertainment","Tell myself I will save it, then slowly spend it"]'::jsonb, 'food', true),
('v2-food-006', 'Which university meal describes you best?', 'multiple_choice', '["A proper meal I prepared","Food from a campus restaurant","Instant noodles","Snacks pretending to be a meal"]'::jsonb, 'food', true),
('v2-food-007', 'You order food and receive the wrong meal. What do you do?', 'multiple_choice', '["Politely ask for the correct order","Eat it anyway","Ask for a refund through the app","Let my friend handle the complaint"]'::jsonb, 'food', true),
('v2-food-008', 'What is your biggest unnecessary expense?', 'multiple_choice', '["Food delivery","Clothes","Subscriptions","Random small purchases"]'::jsonb, 'food', true),
('v2-food-009', 'Your friend says they will pay you back later. What do you do?', 'multiple_choice', '["Trust them and forget about it","Send a reminder later","Request the money immediately","Keep track of every cent"]'::jsonb, 'food', true),
('v2-food-010', 'How do you behave at an all-you-can-eat restaurant?', 'multiple_choice', '["Eat a normal amount","Try to get my money''s worth","Take too much food","Focus mostly on dessert"]'::jsonb, 'food', true),
('v2-personality-001', 'Your alarm goes off in the morning. What do you do?', 'multiple_choice', '["Get up immediately","Snooze it once","Snooze it several times","Turn it off without remembering"]'::jsonb, 'personality', true),
('v2-personality-002', 'Your room becomes messy. When do you clean it?', 'multiple_choice', '["Before it becomes messy","As soon as I notice","When someone is coming over","When I can no longer find anything"]'::jsonb, 'personality', true),
('v2-personality-003', 'You make a small embarrassing mistake in public. What happens next?', 'multiple_choice', '["I laugh at myself","I pretend nothing happened","I think about it for the rest of the day","I remember it randomly for several years"]'::jsonb, 'personality', true),
('v2-personality-004', 'Someone compliments you. How do you respond?', 'multiple_choice', '["Say thank you confidently","Compliment them back","Make a joke","Deny the compliment"]'::jsonb, 'personality', true),
('v2-personality-005', 'You have an important task to complete. How do you begin?', 'multiple_choice', '["Start immediately","Make a detailed plan first","Complete several unrelated tasks first","Wait until the pressure feels real"]'::jsonb, 'personality', true),
('v2-personality-006', 'You have to make a difficult decision. What do you do?', 'multiple_choice', '["Trust my first instinct","Make a pros-and-cons list","Ask several people for advice","Avoid deciding until I have no choice"]'::jsonb, 'personality', true),
('v2-personality-007', 'Someone disagrees with your opinion. What do you do?', 'multiple_choice', '["Have a calm discussion","Try to change their mind","Agree to disagree","Search online to prove I am right"]'::jsonb, 'personality', true),
('v2-personality-008', 'You are running late. What message do you send?', 'multiple_choice', '["\"I am on my way.\"","\"I will be there in five minutes.\"","A detailed explanation of what happened","Nothing until I arrive"]'::jsonb, 'personality', true),
('v2-personality-009', 'You receive instructions for assembling something. What do you do?', 'multiple_choice', '["Read every step carefully","Look at the pictures","Try to figure it out myself","Ask someone else to do it"]'::jsonb, 'personality', true),
('v2-personality-010', 'How do you usually handle awkward silence?', 'multiple_choice', '["Start a new conversation","Make a joke","Check my phone","Let the silence continue"]'::jsonb, 'personality', true),
('v2-dating-001', 'Your crush views your story almost immediately. What do you think?', 'multiple_choice', '["It probably means nothing","They were waiting for me to post","The algorithm showed it first","I start analyzing everything"]'::jsonb, 'dating', true),
('v2-dating-002', 'Someone you like takes several hours to reply. What do you do?', 'multiple_choice', '["Continue with my day","Match their response time","Ask my friends what it means","Check whether they have been active"]'::jsonb, 'dating', true),
('v2-dating-003', 'What is your flirting style?', 'multiple_choice', '["Direct and confident","Playful teasing","Sending memes","Avoiding the person completely"]'::jsonb, 'dating', true),
('v2-dating-004', 'Your friend wants to set you up with someone. What do you do?', 'multiple_choice', '["Agree immediately","Ask to see their profile first","Refuse because it sounds awkward","Investigate the person online"]'::jsonb, 'dating', true),
('v2-dating-005', 'You realize your friend likes the same person as you. What do you do?', 'multiple_choice', '["Talk to my friend honestly","Step aside","Continue pursuing the person","Pretend I never liked them"]'::jsonb, 'dating', true),
('v2-hypothetical-001', 'You suddenly receive a free weekend with no responsibilities. What do you do?', 'multiple_choice', '["Go on a spontaneous trip","Stay home and recharge","Make plans with friends","Start a new hobby or project"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-002', 'You become famous overnight. What is the first thing you do?', 'multiple_choice', '["Hire someone to manage everything","Read every comment about me","Help my friends and family","Disappear from the internet"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-003', 'You can remove one inconvenience from your life forever. Which do you choose?', 'multiple_choice', '["Traffic and commuting","Waiting in lines","Slow internet","Group project problems"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-004', 'You are given one extra hour every day. How do you use it?', 'multiple_choice', '["Sleep","Study or work","Exercise","Watch shows or use social media"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-005', 'You must live without one thing for a month. Which would be easiest?', 'multiple_choice', '["Social media","Video games","Streaming services","Takeout food"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-006', 'You can instantly master one skill. Which do you choose?', 'multiple_choice', '["Speaking every language","Playing any instrument","Coding anything","Becoming extremely confident"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-007', 'You are stuck in an elevator with strangers. What do you do?', 'multiple_choice', '["Start a conversation","Make jokes about the situation","Stay completely quiet","Try to solve the problem myself"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-008', 'You accidentally become the leader of a large club. What do you do?', 'multiple_choice', '["Take the role seriously","Delegate everything","Use the position to make fun events","Look for a way to resign"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-009', 'You can read one person''s mind for a day. Who do you choose?', 'multiple_choice', '["My best friend","My crush","A professor","A famous person"]'::jsonb, 'hypothetical', true),
('v2-hypothetical-010', 'You wake up invisible for one day. What do you do?', 'multiple_choice', '["Explore places I normally cannot enter","Listen to private conversations","Play harmless pranks","Stay home because the situation is terrifying"]'::jsonb, 'hypothetical', true),
('v2-short-001', 'Which celebrity would you most want to meet?', 'short_answer', NULL, 'entertainment', true),
('v2-short-002', 'What is your most-used app?', 'short_answer', NULL, 'technology', true),
('v2-short-003', 'What food could you eat every week?', 'short_answer', NULL, 'food', true),
('v2-short-004', 'What is your current comfort show?', 'short_answer', NULL, 'entertainment', true),
('v2-short-005', 'What is one course you would never take again?', 'short_answer', NULL, 'university', true),
('v2-short-006', 'What fictional character would you trust with your life?', 'short_answer', NULL, 'entertainment', true),
('v2-short-007', 'What is your most embarrassing habit?', 'short_answer', NULL, 'personality', true),
('v2-short-008', 'What would you buy first if money did not matter?', 'short_answer', NULL, 'hypothetical', true),
('v2-short-009', 'What is your dream vacation destination?', 'short_answer', NULL, 'hypothetical', true),
('v2-short-010', 'What is your most controversial food opinion?', 'short_answer', NULL, 'food', true),
('v2-short-011', 'What skill do you wish you could instantly learn?', 'short_answer', NULL, 'personality', true),
('v2-short-012', 'What song have you played too many times?', 'short_answer', NULL, 'entertainment', true),
('v2-short-013', 'What is the worst excuse you have used for being late?', 'short_answer', NULL, 'personality', true),
('v2-short-014', 'What is one app you could not delete?', 'short_answer', NULL, 'technology', true),
('v2-short-015', 'What is the strangest thing currently in your room?', 'short_answer', NULL, 'personality', true),
('v2-short-016', 'What is your go-to late-night meal?', 'short_answer', NULL, 'food', true),
('v2-short-017', 'What is your biggest university regret?', 'short_answer', NULL, 'university', true),
('v2-short-018', 'Which professor would survive a zombie apocalypse?', 'short_answer', NULL, 'university', true),
('v2-short-019', 'What is the worst assignment you have ever received?', 'short_answer', NULL, 'university', true),
('v2-short-020', 'What is the longest you have procrastinated on something?', 'short_answer', NULL, 'personality', true),
('v2-short-021', 'What is one thing you pretend to understand?', 'short_answer', NULL, 'personality', true),
('v2-short-022', 'What is your most irrational fear?', 'short_answer', NULL, 'personality', true),
('v2-short-023', 'What is your go-to karaoke song?', 'short_answer', NULL, 'entertainment', true),
('v2-short-024', 'What is the weirdest thing you believed as a child?', 'short_answer', NULL, 'personality', true),
('v2-short-025', 'What is your most unnecessary purchase?', 'short_answer', NULL, 'food', true),
('v2-short-026', 'What is one trend you do not understand?', 'short_answer', NULL, 'social', true),
('v2-short-027', 'What is the first thing you would do if you became famous?', 'short_answer', NULL, 'hypothetical', true),
('v2-short-028', 'What is a show everyone likes except you?', 'short_answer', NULL, 'entertainment', true),
('v2-short-029', 'What is one thing that instantly annoys you?', 'short_answer', NULL, 'personality', true),
('v2-short-030', 'What is the worst haircut you have ever had?', 'short_answer', NULL, 'personality', true),
('v2-short-031', 'What would your warning label say?', 'short_answer', NULL, 'personality', true),
('v2-short-032', 'What is your most repeated lie?', 'short_answer', NULL, 'personality', true),
('v2-short-033', 'What is the weirdest excuse you have given a professor?', 'short_answer', NULL, 'university', true),
('v2-short-034', 'What is one thing your friends always make fun of you for?', 'short_answer', NULL, 'social', true),
('v2-short-035', 'Which fictional universe would you live in?', 'short_answer', NULL, 'entertainment', true),
('v2-short-036', 'What is the most embarrassing song in your playlist?', 'short_answer', NULL, 'entertainment', true),
('v2-short-037', 'What is your guilty-pleasure television show?', 'short_answer', NULL, 'entertainment', true),
('v2-short-038', 'What is the worst fashion trend?', 'short_answer', NULL, 'social', true),
('v2-short-039', 'What would you name your autobiography?', 'short_answer', NULL, 'personality', true),
('v2-short-040', 'What is one thing you always lose?', 'short_answer', NULL, 'personality', true)
ON CONFLICT (external_id) DO UPDATE SET
  question_text = EXCLUDED.question_text,
  question_type = EXCLUDED.question_type,
  options = EXCLUDED.options,
  category = EXCLUDED.category,
  is_active = true;

-- Enforce readable short answers on evidence cards
CREATE OR REPLACE FUNCTION submit_answer(p_player_id UUID, p_session_token TEXT, p_answer_text TEXT)
RETURNS JSON AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_gq game_questions%ROWTYPE;
  v_answered INT;
  v_connected INT;
  v_qtype question_type;
  v_trimmed TEXT := trim(p_answer_text);
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id;
  IF v_room.status != 'survey' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  SELECT * INTO v_gq FROM game_questions
  WHERE room_id = v_player.room_id AND question_order = v_room.current_question_index;

  IF v_gq.ends_at < now() THEN RAISE EXCEPTION 'TIME_EXPIRED'; END IF;

  SELECT question_type INTO v_qtype FROM questions WHERE id = v_gq.question_id;

  IF v_trimmed = '' THEN RAISE EXCEPTION 'EMPTY_ANSWER'; END IF;
  IF v_qtype = 'short_answer' AND char_length(v_trimmed) > 40 THEN
    RAISE EXCEPTION 'ANSWER_TOO_LONG';
  END IF;

  INSERT INTO player_answers (room_id, player_id, question_id, answer_text)
  VALUES (v_player.room_id, p_player_id, v_gq.question_id, v_trimmed)
  ON CONFLICT (room_id, player_id, question_id) DO NOTHING;

  SELECT COUNT(*) INTO v_answered FROM player_answers pa
  JOIN game_questions gq ON gq.question_id = pa.question_id AND gq.room_id = pa.room_id
  WHERE pa.room_id = v_player.room_id AND gq.question_order = v_room.current_question_index;

  SELECT COUNT(*) INTO v_connected FROM players
  WHERE room_id = v_player.room_id AND is_connected = true;

  IF v_answered >= v_connected AND v_connected > 0 THEN
    PERFORM advance_survey_question(p_player_id, p_session_token, true);
  END IF;

  RETURN json_build_object('answered_count', v_answered, 'total', v_connected);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION start_game(p_player_id UUID, p_session_token TEXT)
RETURNS VOID AS $$
DECLARE
  v_player players%ROWTYPE;
  v_room rooms%ROWTYPE;
  v_count INT;
  v_mc_count INT;
  v_sa_count INT;
  v_mc_ids UUID[];
  v_sa_id UUID;
  v_order INT := 1;
  v_qid UUID;
BEGIN
  SELECT * INTO v_player FROM validate_player(p_player_id, p_session_token);
  IF NOT FOUND THEN RAISE EXCEPTION 'INVALID_SESSION'; END IF;
  IF NOT v_player.is_host THEN RAISE EXCEPTION 'NOT_HOST'; END IF;

  SELECT * INTO v_room FROM rooms WHERE id = v_player.room_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ROOM_NOT_FOUND'; END IF;
  IF v_room.status != 'lobby' THEN RAISE EXCEPTION 'INVALID_STATE'; END IF;

  SELECT COUNT(*) INTO v_count FROM players
  WHERE room_id = v_player.room_id AND is_connected = true;
  IF v_count < 3 THEN RAISE EXCEPTION 'NOT_ENOUGH_PLAYERS'; END IF;

  SELECT COUNT(*) INTO v_mc_count FROM questions
  WHERE question_type = 'multiple_choice' AND is_active = true;
  SELECT COUNT(*) INTO v_sa_count FROM questions
  WHERE question_type = 'short_answer' AND is_active = true;

  IF v_mc_count < 7 THEN
    RAISE EXCEPTION 'MISSING_QUESTIONS: need at least 7 multiple-choice questions in database';
  END IF;
  IF v_sa_count < 1 THEN
    RAISE EXCEPTION 'MISSING_QUESTIONS: need at least 1 short-answer question in database';
  END IF;

  DELETE FROM player_answers WHERE room_id = v_player.room_id;
  DELETE FROM game_questions WHERE room_id = v_player.room_id;

  WITH by_category AS (
    SELECT DISTINCT ON (category) id
    FROM questions
    WHERE question_type = 'multiple_choice' AND is_active = true AND category IS NOT NULL
    ORDER BY category, random()
  ),
  picked AS (
    SELECT id FROM by_category ORDER BY random()
  ),
  need_more AS (
    SELECT GREATEST(0, 7 - (SELECT COUNT(*) FROM picked)) AS n
  ),
  extras AS (
    SELECT q.id
    FROM questions q, need_more nm
    WHERE q.question_type = 'multiple_choice' AND q.is_active = true
      AND q.id NOT IN (SELECT id FROM picked)
    ORDER BY random()
    LIMIT (SELECT n FROM need_more)
  ),
  combined AS (
    SELECT id FROM picked
    UNION ALL
    SELECT id FROM extras
  )
  SELECT array_agg(id) INTO v_mc_ids FROM (
    SELECT id FROM combined ORDER BY random() LIMIT 7
  ) shuffled;

  SELECT id INTO v_sa_id FROM questions
  WHERE question_type = 'short_answer' AND is_active = true
  ORDER BY random() LIMIT 1;

  FOREACH v_qid IN ARRAY v_mc_ids LOOP
    INSERT INTO game_questions (room_id, question_id, question_order)
    VALUES (v_player.room_id, v_qid, v_order);
    v_order := v_order + 1;
  END LOOP;

  INSERT INTO game_questions (room_id, question_id, question_order)
  VALUES (v_player.room_id, v_sa_id, 8);

  UPDATE rooms SET
    status = 'survey',
    current_question_index = 1,
    current_round = 0,
    updated_at = now()
  WHERE id = v_player.room_id;

  PERFORM advance_survey_question(p_player_id, p_session_token, true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
