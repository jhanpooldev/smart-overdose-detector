--
-- PostgreSQL database dump
--

\restrict HEKzSPvV7jgcgbhwmsifGZFydKjvnbgastk1pNwFfMOCqODwzu8q5o13KZ7a9h3

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

-- Started on 2026-04-21 23:25:25

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 224 (class 1259 OID 16413)
-- Name: biometric_signals; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.biometric_signals (
    signal_id integer NOT NULL,
    device_id integer,
    "time" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    heart_rate integer,
    spo2 numeric(5,2),
    resp_rate integer
);


ALTER TABLE public.biometric_signals OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 16412)
-- Name: biometric_signals_signal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.biometric_signals_signal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.biometric_signals_signal_id_seq OWNER TO postgres;

--
-- TOC entry 5067 (class 0 OID 0)
-- Dependencies: 223
-- Name: biometric_signals_signal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.biometric_signals_signal_id_seq OWNED BY public.biometric_signals.signal_id;


--
-- TOC entry 222 (class 1259 OID 16400)
-- Name: devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.devices (
    device_id integer NOT NULL,
    patient_id integer,
    device_type character varying(100),
    status character varying(50)
);


ALTER TABLE public.devices OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 16399)
-- Name: devices_device_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.devices_device_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.devices_device_id_seq OWNER TO postgres;

--
-- TOC entry 5068 (class 0 OID 0)
-- Dependencies: 221
-- Name: devices_device_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.devices_device_id_seq OWNED BY public.devices.device_id;


--
-- TOC entry 228 (class 1259 OID 16443)
-- Name: emergency_contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emergency_contacts (
    contact_id integer NOT NULL,
    full_name character varying(150),
    phone_number character varying(20),
    relationship character varying(50)
);


ALTER TABLE public.emergency_contacts OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 16442)
-- Name: emergency_contacts_contact_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.emergency_contacts_contact_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.emergency_contacts_contact_id_seq OWNER TO postgres;

--
-- TOC entry 5069 (class 0 OID 0)
-- Dependencies: 227
-- Name: emergency_contacts_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.emergency_contacts_contact_id_seq OWNED BY public.emergency_contacts.contact_id;


--
-- TOC entry 229 (class 1259 OID 16450)
-- Name: patient_contacts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patient_contacts (
    patient_id integer NOT NULL,
    contact_id integer NOT NULL
);


ALTER TABLE public.patient_contacts OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 16390)
-- Name: patients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.patients (
    patient_id integer NOT NULL,
    first_name character varying(100),
    last_name character varying(100),
    birth_date date,
    base_bkl_profile text
);


ALTER TABLE public.patients OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 16389)
-- Name: patients_patient_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.patients_patient_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.patients_patient_id_seq OWNER TO postgres;

--
-- TOC entry 5070 (class 0 OID 0)
-- Dependencies: 219
-- Name: patients_patient_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.patients_patient_id_seq OWNED BY public.patients.patient_id;


--
-- TOC entry 226 (class 1259 OID 16427)
-- Name: risk_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.risk_events (
    event_id integer NOT NULL,
    patient_id integer,
    risk_level character varying(50),
    probability numeric(5,2),
    location text,
    event_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.risk_events OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 16426)
-- Name: risk_events_event_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.risk_events_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.risk_events_event_id_seq OWNER TO postgres;

--
-- TOC entry 5071 (class 0 OID 0)
-- Dependencies: 225
-- Name: risk_events_event_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.risk_events_event_id_seq OWNED BY public.risk_events.event_id;


--
-- TOC entry 4882 (class 2604 OID 16416)
-- Name: biometric_signals signal_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.biometric_signals ALTER COLUMN signal_id SET DEFAULT nextval('public.biometric_signals_signal_id_seq'::regclass);


--
-- TOC entry 4881 (class 2604 OID 16403)
-- Name: devices device_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices ALTER COLUMN device_id SET DEFAULT nextval('public.devices_device_id_seq'::regclass);


--
-- TOC entry 4886 (class 2604 OID 16446)
-- Name: emergency_contacts contact_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emergency_contacts ALTER COLUMN contact_id SET DEFAULT nextval('public.emergency_contacts_contact_id_seq'::regclass);


--
-- TOC entry 4880 (class 2604 OID 16393)
-- Name: patients patient_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients ALTER COLUMN patient_id SET DEFAULT nextval('public.patients_patient_id_seq'::regclass);


--
-- TOC entry 4884 (class 2604 OID 16430)
-- Name: risk_events event_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.risk_events ALTER COLUMN event_id SET DEFAULT nextval('public.risk_events_event_id_seq'::regclass);


--
-- TOC entry 5056 (class 0 OID 16413)
-- Dependencies: 224
-- Data for Name: biometric_signals; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.biometric_signals (signal_id, device_id, "time", heart_rate, spo2, resp_rate) FROM stdin;
1	1	2026-04-21 23:05:32.904531	75	98.00	16
\.


--
-- TOC entry 5054 (class 0 OID 16400)
-- Dependencies: 222
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.devices (device_id, patient_id, device_type, status) FROM stdin;
1	1	Smartwatch Samsung	Activo
\.


--
-- TOC entry 5060 (class 0 OID 16443)
-- Dependencies: 228
-- Data for Name: emergency_contacts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.emergency_contacts (contact_id, full_name, phone_number, relationship) FROM stdin;
1	Maria Perez	987654321	Hija
\.


--
-- TOC entry 5061 (class 0 OID 16450)
-- Dependencies: 229
-- Data for Name: patient_contacts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patient_contacts (patient_id, contact_id) FROM stdin;
1	1
\.


--
-- TOC entry 5052 (class 0 OID 16390)
-- Dependencies: 220
-- Data for Name: patients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.patients (patient_id, first_name, last_name, birth_date, base_bkl_profile) FROM stdin;
1	Juan	Perez	1950-05-10	Normal
\.


--
-- TOC entry 5058 (class 0 OID 16427)
-- Dependencies: 226
-- Data for Name: risk_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.risk_events (event_id, patient_id, risk_level, probability, location, event_time) FROM stdin;
1	1	Alto	92.50	Sala	2026-04-21 23:05:32.904531
\.


--
-- TOC entry 5072 (class 0 OID 0)
-- Dependencies: 223
-- Name: biometric_signals_signal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.biometric_signals_signal_id_seq', 1, true);


--
-- TOC entry 5073 (class 0 OID 0)
-- Dependencies: 221
-- Name: devices_device_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.devices_device_id_seq', 1, true);


--
-- TOC entry 5074 (class 0 OID 0)
-- Dependencies: 227
-- Name: emergency_contacts_contact_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.emergency_contacts_contact_id_seq', 1, true);


--
-- TOC entry 5075 (class 0 OID 0)
-- Dependencies: 219
-- Name: patients_patient_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.patients_patient_id_seq', 1, true);


--
-- TOC entry 5076 (class 0 OID 0)
-- Dependencies: 225
-- Name: risk_events_event_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.risk_events_event_id_seq', 1, true);


--
-- TOC entry 4892 (class 2606 OID 16420)
-- Name: biometric_signals biometric_signals_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.biometric_signals
    ADD CONSTRAINT biometric_signals_pkey PRIMARY KEY (signal_id);


--
-- TOC entry 4890 (class 2606 OID 16406)
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (device_id);


--
-- TOC entry 4896 (class 2606 OID 16449)
-- Name: emergency_contacts emergency_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emergency_contacts
    ADD CONSTRAINT emergency_contacts_pkey PRIMARY KEY (contact_id);


--
-- TOC entry 4898 (class 2606 OID 16456)
-- Name: patient_contacts patient_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_contacts
    ADD CONSTRAINT patient_contacts_pkey PRIMARY KEY (patient_id, contact_id);


--
-- TOC entry 4888 (class 2606 OID 16398)
-- Name: patients patients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patients
    ADD CONSTRAINT patients_pkey PRIMARY KEY (patient_id);


--
-- TOC entry 4894 (class 2606 OID 16436)
-- Name: risk_events risk_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.risk_events
    ADD CONSTRAINT risk_events_pkey PRIMARY KEY (event_id);


--
-- TOC entry 4900 (class 2606 OID 16421)
-- Name: biometric_signals biometric_signals_device_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.biometric_signals
    ADD CONSTRAINT biometric_signals_device_id_fkey FOREIGN KEY (device_id) REFERENCES public.devices(device_id) ON DELETE CASCADE;


--
-- TOC entry 4899 (class 2606 OID 16407)
-- Name: devices devices_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- TOC entry 4902 (class 2606 OID 16462)
-- Name: patient_contacts patient_contacts_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_contacts
    ADD CONSTRAINT patient_contacts_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.emergency_contacts(contact_id) ON DELETE CASCADE;


--
-- TOC entry 4903 (class 2606 OID 16457)
-- Name: patient_contacts patient_contacts_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.patient_contacts
    ADD CONSTRAINT patient_contacts_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


--
-- TOC entry 4901 (class 2606 OID 16437)
-- Name: risk_events risk_events_patient_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.risk_events
    ADD CONSTRAINT risk_events_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES public.patients(patient_id) ON DELETE CASCADE;


-- Completed on 2026-04-21 23:25:26

--
-- PostgreSQL database dump complete
--

\unrestrict HEKzSPvV7jgcgbhwmsifGZFydKjvnbgastk1pNwFfMOCqODwzu8q5o13KZ7a9h3

