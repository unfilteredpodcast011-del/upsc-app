-- Supabase Database Schema for ExamPrep

-- 1. Profiles / Students Table
CREATE TABLE IF NOT EXISTS public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT NOT NULL,
    district TEXT NOT NULL,
    target_exam TEXT NOT NULL CHECK (target_exam IN ('UPSC', 'TNPSC')),
    years_trying TEXT NOT NULL,
    education_status TEXT NOT NULL CHECK (education_status IN ('studying', 'graduated')),
    education_level TEXT, -- 'school' or 'college'
    school_standard TEXT, -- if school
    college_degree_type TEXT, -- 'UG' or 'PG'
    college_degree_name TEXT, -- e.g. B.E, B.Sc, B.A
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Questions Table
CREATE TABLE IF NOT EXISTS public.questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_text TEXT NOT NULL,
    option_a TEXT NOT NULL,
    option_b TEXT NOT NULL,
    option_c TEXT NOT NULL,
    option_d TEXT NOT NULL,
    correct_answer TEXT NOT NULL CHECK (correct_answer IN ('A', 'B', 'C', 'D')),
    exam TEXT NOT NULL CHECK (exam IN ('UPSC', 'TNPSC')),
    subject TEXT NOT NULL,
    topic TEXT,
    difficulty TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'published',
    batch_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tests Table (Real Exam Patterns)
CREATE TABLE IF NOT EXISTS public.tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    exam TEXT NOT NULL CHECK (exam IN ('UPSC', 'TNPSC')),
    category TEXT NOT NULL, -- 'daily', 'subject', 'full_mock'
    duration_minutes INT NOT NULL DEFAULT 60,
    total_marks DOUBLE PRECISION NOT NULL DEFAULT 100,
    negative_marking DOUBLE PRECISION NOT NULL DEFAULT 0.33,
    price_paise INT NOT NULL DEFAULT 100, -- Rs. 1 = 100 paise
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Test Questions Junction Table
CREATE TABLE IF NOT EXISTS public.test_questions (
    test_id UUID REFERENCES public.tests(id) ON DELETE CASCADE,
    question_id UUID REFERENCES public.questions(id) ON DELETE CASCADE,
    question_order INT DEFAULT 1,
    PRIMARY KEY (test_id, question_id)
);

-- 5. Payments Table (Rs. 1 via Razorpay)
CREATE TABLE IF NOT EXISTS public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id),
    test_id UUID REFERENCES public.tests(id),
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    amount_paise INT NOT NULL DEFAULT 100,
    status TEXT NOT NULL DEFAULT 'captured',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Exam Results / Test Attempts Table
CREATE TABLE IF NOT EXISTS public.test_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID REFERENCES public.students(id),
    test_id UUID REFERENCES public.tests(id),
    score DOUBLE PRECISION NOT NULL,
    total_marks DOUBLE PRECISION NOT NULL,
    correct_count INT NOT NULL,
    wrong_count INT NOT NULL,
    skipped_count INT NOT NULL,
    time_taken_seconds INT NOT NULL,
    answers_json JSONB NOT NULL, -- stores question_id, selected_option, is_correct
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Enable Row Level Security (RLS)
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_attempts ENABLE ROW LEVEL SECURITY;

-- Allow public read/write for app usage with anon key
CREATE POLICY "Public students access" ON public.students FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public questions read" ON public.questions FOR SELECT USING (true);
CREATE POLICY "Public tests read" ON public.tests FOR SELECT USING (true);
CREATE POLICY "Public test_questions read" ON public.test_questions FOR SELECT USING (true);
CREATE POLICY "Public payments insert/read" ON public.payments FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Public attempts insert/read" ON public.test_attempts FOR ALL USING (true) WITH CHECK (true);
