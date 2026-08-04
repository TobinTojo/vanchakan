import type { Question } from '@/types';

export const QUESTION_BANK: Omit<Question, 'id'>[] = [
  {
    question_text: 'If you suddenly had a free weekend with no responsibilities, what would you most likely do?',
    question_type: 'multiple_choice',
    options: ['Binge a TV show or movies', 'Go on a spontaneous trip', 'Sleep most of the time', 'Try a new hobby or project'],
    category: 'School',
  },
  {
    question_text: 'It is the night before an important exam. What are you most likely doing?',
    question_type: 'multiple_choice',
    options: ['Studying seriously and reviewing notes', 'Cramming with friends on a video call', 'Convincing yourself you already know enough', 'Accepting your fate and going to sleep'],
    category: 'School',
  },
  {
    question_text: 'What is your usual role in a group project?',
    question_type: 'multiple_choice',
    options: ['The organizer who keeps everyone on track', 'The one who does most of the work', 'The creative idea person', 'The last-minute contributor'],
    category: 'School',
  },
  {
    question_text: 'What is the most tempting distraction while studying?',
    question_type: 'multiple_choice',
    options: ['Social media', 'YouTube or streaming', 'Texting friends', 'Snacks and wandering around'],
    category: 'School',
  },
  {
    question_text: 'Finals are finally over. What is your first move?',
    question_type: 'multiple_choice',
    options: ['Celebrate with friends', 'Sleep for a long time', 'Travel or go home', 'Start a new show or game'],
    category: 'School',
  },
  {
    question_text: 'You and your friends are starting a game night. What game are you most likely to suggest?',
    question_type: 'multiple_choice',
    options: ['A competitive shooter or battle royale', 'A party game where everyone can laugh and yell', 'A chill co-op game where everyone works together', 'A nostalgic game you played as a kid'],
    category: 'Entertainment',
  },
  {
    question_text: 'It is movie night with friends. Which type of movie are you most excited to watch?',
    question_type: 'multiple_choice',
    options: ['A big action blockbuster', 'A horror movie that makes everyone scream', 'A dumb comedy everyone can quote later', 'A nostalgic childhood favorite'],
    category: 'Entertainment',
  },
];

export const SHORT_ANSWER_BANK: Omit<Question, 'id'>[] = [
  { question_text: 'Which celebrity would you most want to meet in real life?', question_type: 'short_answer', options: null, category: 'Entertainment' },
  { question_text: 'What is a food you could eat every week?', question_type: 'short_answer', options: null, category: 'Food' },
  { question_text: 'What is your most-used app?', question_type: 'short_answer', options: null, category: 'Technology' },
  { question_text: 'What fictional character would you trust with your life?', question_type: 'short_answer', options: null, category: 'Entertainment' },
  { question_text: 'What is your most embarrassing habit?', question_type: 'short_answer', options: null, category: 'Embarrassing habits' },
  { question_text: 'What is one thing you would buy if money did not matter?', question_type: 'short_answer', options: null, category: 'Hypothetical' },
  { question_text: 'What is a show you would recommend to everyone?', question_type: 'short_answer', options: null, category: 'Entertainment' },
  { question_text: 'What is your dream vacation destination?', question_type: 'short_answer', options: null, category: 'Travel' },
  { question_text: 'What is your most controversial food opinion?', question_type: 'short_answer', options: null, category: 'Food' },
  { question_text: 'What is a skill you wish you had?', question_type: 'short_answer', options: null, category: 'Personality' },
];
