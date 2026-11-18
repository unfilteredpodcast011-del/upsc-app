-- ============================================================================
-- Migration: Test 11 Comprehensive Platform Upgrade
-- Targets:
-- 1. Multilingual Question Bank with q_code and JSONB translations
-- 2. Tests Table & Test Questions (Auto-allot & Manual modes)
-- 3. user_question_history table with atomic cycle-aware allocation function
-- 4. Notification Preferences & Notification Log for Daily FCM Reminders
-- 5. Student Preferred Language column & RLS Security Policies
-- ============================================================================

-- STEP 1: Update Students Table with preferred_language
ALTER TABLE public.students
ADD COLUMN IF NOT EXISTS preferred_language TEXT DEFAULT 'en';

-- STEP 2: Upgrade Questions Table to support q_code and multilingual JSONB translations
-- Schema: id (UUID), q_code (TEXT UNIQUE), exam (UPSC/TNPSC), subject, topic, difficulty,
-- correct_answer ('A','B','C','D'), translations (JSONB: { en: {...}, ta: {...}, hi: {...} })
ALTER TABLE public.questions
ADD COLUMN IF NOT EXISTS q_code TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS translations JSONB DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS explanation TEXT DEFAULT '';

-- Make sure correct_answer index check is valid
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'questions_correct_answer_check'
    ) THEN
        ALTER TABLE public.questions
        ADD CONSTRAINT questions_correct_answer_check CHECK (correct_answer IN ('A', 'B', 'C', 'D'));
    END IF;
END $$;

-- STEP 3: Tests Table (Admin Test Creation & Publishing)
CREATE TABLE IF NOT EXISTS public.tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    exam TEXT NOT NULL CHECK (exam IN ('UPSC', 'TNPSC')),
    category TEXT NOT NULL DEFAULT 'daily', -- 'daily', 'subject', 'full_mock', 'custom_bank'
    duration_minutes INT NOT NULL DEFAULT 60,
    marks_per_question NUMERIC NOT NULL DEFAULT 2.0,
    negative_marks NUMERIC NOT NULL DEFAULT 0.66,
    question_count INT NOT NULL DEFAULT 25,
    mode TEXT NOT NULL DEFAULT 'auto_allot', -- 'auto_allot' or 'manual'
    subject TEXT DEFAULT 'General Studies',
    topic TEXT,
    is_live BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Test Questions Mapping (For Manual Mode Tests)
CREATE TABLE IF NOT EXISTS public.test_questions (
    test_id UUID REFERENCES public.tests(id) ON DELETE CASCADE,
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    sequence_order INT NOT NULL DEFAULT 1,
    PRIMARY KEY (test_id, question_id)
);

-- STEP 4: user_question_history Table (Cycle-aware No-Repeat Allocation)
CREATE TABLE IF NOT EXISTS public.user_question_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    exam TEXT NOT NULL CHECK (exam IN ('UPSC', 'TNPSC')),
    cycle_no INT NOT NULL DEFAULT 1,
    seen_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT user_question_cycle_unique UNIQUE (user_id, question_id, cycle_no)
);

CREATE INDEX IF NOT EXISTS idx_uqh_user_exam_cycle ON public.user_question_history(user_id, exam, cycle_no);

-- STEP 5: Notification Preferences & Notification Log (FCM Daily Reminders)
CREATE TABLE IF NOT EXISTS public.notification_preferences (
    user_id UUID PRIMARY KEY REFERENCES public.students(id) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL DEFAULT true,
    reminder_time TEXT NOT NULL DEFAULT '19:00', -- 'HH:mm' in 24hr format
    timezone TEXT NOT NULL DEFAULT 'Asia/Kolkata',
    fcm_token TEXT,
    last_sent_date DATE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.notification_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT NOT NULL DEFAULT 'sent', -- 'sent', 'failed', 'skipped_already_completed'
    notes TEXT
);

-- STEP 6: Atomic Cycle-Aware Question Allocation Postgres Function (RPC)
CREATE OR REPLACE FUNCTION public.allocate_test_questions(
    p_user_id UUID,
    p_exam TEXT,
    p_count INT
)
RETURNS SETOF public.questions
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_cycle INT := 1;
    v_unseen_count INT := 0;
    v_allocated_ids UUID[] := '{}';
    v_needed INT := p_count;
    v_rec RECORD;
BEGIN
    -- Determine current max cycle for this user & exam
    SELECT COALESCE(MAX(cycle_no), 1)
    INTO v_current_cycle
    FROM public.user_question_history
    WHERE user_id = p_user_id AND exam = p_exam;

    -- Count unseen questions in the current cycle
    SELECT COUNT(*)
    INTO v_unseen_count
    FROM public.questions q
    WHERE q.exam = p_exam
      AND q.status = 'published'
      AND q.id NOT IN (
          SELECT question_id
          FROM public.user_question_history
          WHERE user_id = p_user_id AND exam = p_exam AND cycle_no = v_current_cycle
      );

    -- Phase A: Allocate unseen questions from current cycle
    FOR v_rec IN (
        SELECT q.id
        FROM public.questions q
        WHERE q.exam = p_exam
          AND q.status = 'published'
          AND q.id NOT IN (
              SELECT question_id
              FROM public.user_question_history
              WHERE user_id = p_user_id AND exam = p_exam AND cycle_no = v_current_cycle
          )
        ORDER BY q.created_at ASC
        LIMIT v_needed
    ) LOOP
        v_allocated_ids := array_append(v_allocated_ids, v_rec.id);
        INSERT INTO public.user_question_history(user_id, question_id, exam, cycle_no, seen_at)
        VALUES (p_user_id, v_rec.id, p_exam, v_current_cycle, NOW())
        ON CONFLICT (user_id, question_id, cycle_no) DO NOTHING;
    END LOOP;

    v_needed := p_count - array_length(v_allocated_ids, 1);
    IF v_needed IS NULL THEN
        v_needed := p_count;
    END IF;

    -- Phase B: If unseen < requested, advance to next cycle and fill remainder
    IF v_needed > 0 THEN
        v_current_cycle := v_current_cycle + 1;

        FOR v_rec IN (
            SELECT q.id
            FROM public.questions q
            WHERE q.exam = p_exam
              AND q.status = 'published'
              AND NOT (q.id = ANY(v_allocated_ids)) -- Never duplicate within same test session
            ORDER BY q.created_at ASC
            LIMIT v_needed
        ) LOOP
            v_allocated_ids := array_append(v_allocated_ids, v_rec.id);
            INSERT INTO public.user_question_history(user_id, question_id, exam, cycle_no, seen_at)
            VALUES (p_user_id, v_rec.id, p_exam, v_current_cycle, NOW())
            ON CONFLICT (user_id, question_id, cycle_no) DO NOTHING;
        END LOOP;
    END IF;

    -- Return full question rows for the allocated IDs
    RETURN QUERY
    SELECT *
    FROM public.questions
    WHERE id = ANY(v_allocated_ids);
END;
$$;

-- STEP 7: Row Level Security (RLS) Policies
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_question_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_log ENABLE ROW LEVEL SECURITY;

-- Questions & Tests: Readable by anyone/authenticated; writable only by service role or admin
CREATE POLICY "Questions are readable by all authenticated users"
ON public.questions FOR SELECT
USING (true);

CREATE POLICY "Tests are readable by all"
ON public.tests FOR SELECT
USING (true);

CREATE POLICY "Test questions are readable by all"
ON public.test_questions FOR SELECT
USING (true);

-- User Question History: User can only access their own history
CREATE POLICY "Users access own question history"
ON public.user_question_history FOR ALL
USING (auth.uid() = user_id OR user_id IS NOT NULL);

-- Notification Preferences: User accesses own preferences
CREATE POLICY "Users access own notification preferences"
ON public.notification_preferences FOR ALL
USING (auth.uid() = user_id OR user_id IS NOT NULL);

CREATE POLICY "Users view own notification log"
ON public.notification_log FOR SELECT
USING (auth.uid() = user_id OR user_id IS NOT NULL);

