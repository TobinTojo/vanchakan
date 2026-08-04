import multipleChoiceData from './multipleChoice.json';
import shortAnswerData from './shortAnswer.json';

export type QuestionCategory =
  | 'university'
  | 'social'
  | 'technology'
  | 'entertainment'
  | 'food'
  | 'personality'
  | 'dating'
  | 'hypothetical';

export interface MultipleChoiceQuestion {
  id: string;
  type: 'multiple_choice';
  category: QuestionCategory;
  question: string;
  options: [string, string, string, string];
}

export interface ShortAnswerQuestion {
  id: string;
  type: 'short_answer';
  category: QuestionCategory;
  question: string;
  maxLength: number;
}

export type SurveyQuestion = MultipleChoiceQuestion | ShortAnswerQuestion;

export const multipleChoiceQuestions: MultipleChoiceQuestion[] = multipleChoiceData.map((q) => ({
  id: q.id,
  type: 'multiple_choice' as const,
  category: q.category as QuestionCategory,
  question: q.question,
  options: q.options as [string, string, string, string],
}));

export const shortAnswerQuestions: ShortAnswerQuestion[] = shortAnswerData.map((q) => ({
  id: q.id,
  type: 'short_answer' as const,
  category: q.category as QuestionCategory,
  question: q.question,
  maxLength: q.maxLength,
}));

function shuffle<T>(items: T[]): T[] {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

/** Client-side preview only — production selection happens in start_game RPC. */
export function selectGameQuestions(
  mcPool: MultipleChoiceQuestion[] = multipleChoiceQuestions,
  saPool: ShortAnswerQuestion[] = shortAnswerQuestions
): SurveyQuestion[] {
  const byCategory = new Map<QuestionCategory, MultipleChoiceQuestion[]>();

  for (const question of mcPool) {
    const list = byCategory.get(question.category) ?? [];
    list.push(question);
    byCategory.set(question.category, list);
  }

  const categoryPicks: MultipleChoiceQuestion[] = [];
  for (const questions of byCategory.values()) {
    const pick = shuffle(questions)[0];
    if (pick) categoryPicks.push(pick);
  }

  const pickedIds = new Set(categoryPicks.map((q) => q.id));
  const remaining = shuffle(mcPool.filter((q) => !pickedIds.has(q.id)));
  const selectedMultipleChoice = [...shuffle(categoryPicks), ...remaining].slice(0, 7);
  const selectedShortAnswer = shuffle(saPool)[0];

  if (!selectedShortAnswer) {
    throw new Error('No short-answer questions available');
  }

  return [...shuffle(selectedMultipleChoice), selectedShortAnswer];
}

/** @deprecated Use multipleChoiceQuestions / shortAnswerQuestions */
export const QUESTION_BANK = multipleChoiceQuestions.map((q) => ({
  question_text: q.question,
  question_type: q.type,
  options: [...q.options],
  category: q.category,
}));

/** @deprecated Use shortAnswerQuestions */
export const SHORT_ANSWER_BANK = shortAnswerQuestions.map((q) => ({
  question_text: q.question,
  question_type: q.type,
  options: null,
  category: q.category,
}));
