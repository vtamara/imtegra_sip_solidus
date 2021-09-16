SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: es_co_utf_8; Type: COLLATION; Schema: public; Owner: -
--

CREATE COLLATION public.es_co_utf_8 (provider = libc, locale = 'es_CO.UTF-8');


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: completa_obs(character varying, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.completa_obs(obs character varying, nuevaobs character varying) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
      BEGIN
        RETURN CASE WHEN obs IS NULL THEN nuevaobs
          WHEN obs='' THEN nuevaobs
          WHEN RIGHT(obs, 1)='.' THEN obs || ' ' || nuevaobs
          ELSE obs || '. ' || nuevaobs
        END;
      END; $$;


--
-- Name: divarr(anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.divarr(in_array anyarray) RETURNS SETOF text
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT ($1)[s] FROM generate_series(1,array_upper($1, 1)) AS s;
$_$;


--
-- Name: edad_de_fechanac(integer, integer, integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.edad_de_fechanac(anionac integer, mesnac integer, dianac integer, fechahecho date) RETURNS integer
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
	aniohecho INTEGER = EXTRACT(year FROM fechahecho);
	meshecho INTEGER = EXTRACT(month FROM fechahecho);
	diahecho INTEGER = EXTRACT(day FROM fechahecho);
	na INTEGER;
BEGIN
	na = CASE WHEN anionac IS NULL OR aniohecho IS NULL THEN 
		NULL
	ELSE
		aniohecho - anionac
	END;
	na = CASE WHEN mesnac IS NOT NULL AND meshecho IS NOT NULL AND 
		mesnac > meshecho OR 
		(dianac IS NOT NULL AND diahecho IS NOT NULL 
		  AND dianac > diahecho) THEN
		na - 1
	ELSE
		na
	END;

	RETURN na;

END;$$;


--
-- Name: f_unaccent(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.f_unaccent(text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
      SELECT public.unaccent('public.unaccent', $1)  
      $_$;


--
-- Name: first_element(anyarray); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.first_element(anyarray) RETURNS anyelement
    LANGUAGE sql IMMUTABLE
    AS $_$
            SELECT ($1)[1] ;
            $_$;


--
-- Name: first_element_state(anyarray, anyelement); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.first_element_state(anyarray, anyelement) RETURNS anyarray
    LANGUAGE sql IMMUTABLE
    AS $_$
            SELECT CASE WHEN array_upper($1,1) IS NULL
                THEN array_append($1,$2)
                ELSE $1
            END;
            $_$;


--
-- Name: probapellido(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.probapellido(in_text text) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
	SELECT sum(ppar) FROM (SELECT p, probcadap(p) AS ppar FROM (
		SELECT p FROM divarr(string_to_array(trim($1), ' ')) AS p) 
		AS s) AS s2;
$_$;


--
-- Name: probcadap(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.probcadap(in_text text) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
    SELECT CASE WHEN (SELECT SUM(frec) FROM napellidos)=0 THEN 0
        WHEN (SELECT COUNT(*) FROM napellidos WHERE apellido=$1)=0 THEN 0
        ELSE (SELECT frec/(SELECT SUM(frec) FROM napellidos) 
            FROM napellidos WHERE apellido=$1)
        END
$_$;


--
-- Name: probcadh(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.probcadh(in_text text) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
	SELECT CASE WHEN (SELECT SUM(frec) FROM nhombres)=0 THEN 0
		WHEN (SELECT COUNT(*) FROM nhombres WHERE nombre=$1)=0 THEN 0
		ELSE (SELECT frec/(SELECT SUM(frec) FROM nhombres) 
			FROM nhombres WHERE nombre=$1)
		END
$_$;


--
-- Name: probcadm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.probcadm(in_text text) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
	SELECT CASE WHEN (SELECT SUM(frec) FROM nmujeres)=0 THEN 0
		WHEN (SELECT COUNT(*) FROM nmujeres WHERE nombre=$1)=0 THEN 0
		ELSE (SELECT frec/(SELECT SUM(frec) FROM nmujeres) 
			FROM nmujeres WHERE nombre=$1)
		END
$_$;


--
-- Name: probhombre(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.probhombre(in_text text) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
	SELECT sum(ppar) FROM (SELECT p, peso*probcadh(p) AS ppar FROM (
		SELECT p, CASE WHEN rnum=1 THEN 100 ELSE 1 END AS peso 
		FROM (SELECT p, row_number() OVER () AS rnum FROM 
			divarr(string_to_array(trim($1), ' ')) AS p) 
		AS s) AS s2) AS s3;
$_$;


--
-- Name: probmujer(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.probmujer(in_text text) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $_$
	SELECT sum(ppar) FROM (SELECT p, peso*probcadm(p) AS ppar FROM (
		SELECT p, CASE WHEN rnum=1 THEN 100 ELSE 1 END AS peso 
		FROM (SELECT p, row_number() OVER () AS rnum FROM 
			divarr(string_to_array(trim($1), ' ')) AS p) 
		AS s) AS s2) AS s3;
$_$;


--
-- Name: sip_edad_de_fechanac_fecharef(integer, integer, integer, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sip_edad_de_fechanac_fecharef(anionac integer, mesnac integer, dianac integer, anioref integer, mesref integer, diaref integer) RETURNS integer
    LANGUAGE sql IMMUTABLE
    AS $$
        SELECT CASE 
          WHEN anionac IS NULL THEN NULL
          WHEN anioref IS NULL THEN NULL
          WHEN mesnac IS NULL OR dianac IS NULL OR mesref IS NULL OR diaref IS NULL THEN 
            anioref-anionac 
          WHEN mesnac < mesref THEN
            anioref-anionac
          WHEN mesnac > mesref THEN
            anioref-anionac-1
          WHEN dianac > diaref THEN
            anioref-anionac-1
          ELSE 
            anioref-anionac
        END 
      $$;


--
-- Name: sivel2_gen_polo_id(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sivel2_gen_polo_id(presponsable_id integer) RETURNS integer
    LANGUAGE sql
    AS $$
        WITH RECURSIVE des AS (
          SELECT id, nombre, papa_id 
          FROM sivel2_gen_presponsable WHERE id=presponsable_id 
          UNION SELECT e.id, e.nombre, e.papa_id 
          FROM sivel2_gen_presponsable e INNER JOIN des d ON d.papa_id=e.id) 
        SELECT id FROM des WHERE papa_id IS NULL;
      $$;


--
-- Name: sivel2_gen_polo_nombre(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sivel2_gen_polo_nombre(presponsable_id integer) RETURNS character varying
    LANGUAGE sql
    AS $$
        SELECT CASE 
          WHEN fechadeshabilitacion IS NULL THEN nombre
          ELSE nombre || '(DESHABILITADO)' 
        END 
        FROM sivel2_gen_presponsable 
        WHERE id=sivel2_gen_polo_id(presponsable_id)
      $$;


--
-- Name: soundexesp(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.soundexesp(input text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE STRICT COST 500
    AS $$
DECLARE
	soundex text='';	
	-- para determinar la primera letra
	pri_letra text;
	resto text;
	sustituida text ='';
	-- para quitar adyacentes
	anterior text;
	actual text;
	corregido text;
BEGIN
       -- devolver null si recibi un string en blanco o con espacios en blanco
	IF length(trim(input))= 0 then
		RETURN NULL;
	end IF;
 
 
	-- 1: LIMPIEZA:
		-- pasar a mayuscula, eliminar la letra "H" inicial, los acentos y la enie
		-- 'holá coñó' => 'OLA CONO'
        input=translate(ltrim(trim(upper(input)),'H'),'ÑÁÉÍÓÚÀÈÌÒÙÜ',
            'NAEIOUAEIOUU');
 
		-- eliminar caracteres no alfabéticos (números, símbolos como &,%,",*,!,+, etc.
		input=regexp_replace(input, '[^a-zA-Z]', '', 'g');
 
	-- 2: PRIMERA LETRA ES IMPORTANTE, DEBO ASOCIAR LAS SIMILARES
	--  'vaca' se convierte en 'baca'  y 'zapote' se convierte en 'sapote'
	-- un fenomeno importante es GE y GI se vuelven JE y JI; CA se vuelve KA, etc
	pri_letra =substr(input,1,1);
	resto =substr(input,2);
	CASE 
		when pri_letra IN ('V') then
			sustituida='B';
		when pri_letra IN ('Z','X') then
			sustituida='S';
		when pri_letra IN ('G') AND substr(input,2,1) IN ('E','I') then
			sustituida='J';
		when pri_letra IN('C') AND substr(input,2,1) NOT IN ('H','E','I') then
			sustituida='K';
		else
			sustituida=pri_letra;
 
	end case;
	--corregir el parametro con las consonantes sustituidas:
	input=sustituida || resto;		
 
	-- 3: corregir "letras compuestas" y volverlas una sola
	input=REPLACE(input,'CH','V');
	input=REPLACE(input,'QU','K');
	input=REPLACE(input,'LL','J');
	input=REPLACE(input,'CE','S');
	input=REPLACE(input,'CI','S');
	input=REPLACE(input,'YA','J');
	input=REPLACE(input,'YE','J');
	input=REPLACE(input,'YI','J');
	input=REPLACE(input,'YO','J');
	input=REPLACE(input,'YU','J');
	input=REPLACE(input,'GE','J');
	input=REPLACE(input,'GI','J');
	input=REPLACE(input,'NY','N');
	-- para debug:    --return input;
 
	-- EMPIEZA EL CALCULO DEL SOUNDEX
	-- 4: OBTENER PRIMERA letra
	pri_letra=substr(input,1,1);
 
	-- 5: retener el resto del string
	resto=substr(input,2);
 
	--6: en el resto del string, quitar vocales y vocales fonéticas
	resto=translate(resto,'@AEIOUHWY','@');
 
    --7: convertir las letras foneticamente equivalentes a numeros  
    --   (esto hace que B sea equivalente a V, C con S y Z, etc.)
	resto=translate(resto, 'BPFVCGKSXZDTLMNRQJ', '111122222233455677');
	-- así va quedando la cosa
	soundex=pri_letra || resto;
 
	--8: eliminar números iguales adyacentes (A11233 se vuelve A123)
	anterior=substr(soundex,1,1);
	corregido=anterior;
 
	FOR i IN 2 .. length(soundex) LOOP
		actual = substr(soundex, i, 1);
		IF actual <> anterior THEN
			corregido=corregido || actual;
			anterior=actual;			
		END IF;
	END LOOP;
	-- así va la cosa
	soundex=corregido;
 
	-- 9: siempre retornar un string de 4 posiciones
	soundex=rpad(soundex,4,'0');
	soundex=substr(soundex,1,4);		
 
	-- YA ESTUVO
	RETURN soundex;	
END;	
$$;


--
-- Name: soundexespm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.soundexespm(in_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $_$
SELECT ARRAY_TO_STRING(ARRAY_AGG(soundexesp(s)),' ')
FROM (SELECT UNNEST(STRING_TO_ARRAY(
		REGEXP_REPLACE(TRIM($1), '  *', ' '), ' ')) AS s                
	      ORDER BY 1) AS n;
$_$;


--
-- Name: first(anyelement); Type: AGGREGATE; Schema: public; Owner: -
--

CREATE AGGREGATE public.first(anyelement) (
    SFUNC = public.first_element_state,
    STYPE = anyarray,
    FINALFUNC = public.first_element
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_mailbox_inbound_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_mailbox_inbound_emails (
    id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    message_id character varying NOT NULL,
    message_checksum character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_mailbox_inbound_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_mailbox_inbound_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_mailbox_inbound_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_mailbox_inbound_emails_id_seq OWNED BY public.action_mailbox_inbound_emails.id;


--
-- Name: action_text_rich_texts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_text_rich_texts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    body text,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_text_rich_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_text_rich_texts_id_seq OWNED BY public.action_text_rich_texts.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: acto_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.acto_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: antecedente_combatiente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.antecedente_combatiente (
    id_antecedente integer NOT NULL,
    id_combatiente integer NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: caso_etiqueta_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.caso_etiqueta_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: caso_presponsable_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.caso_presponsable_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_caso_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_caso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_caso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso (
    id integer DEFAULT nextval('public.sivel2_gen_caso_id_seq'::regclass) NOT NULL,
    titulo character varying(50),
    fecha date NOT NULL,
    hora character varying(10),
    duracion character varying(10),
    memo text NOT NULL,
    grconfiabilidad character varying(5),
    gresclarecimiento character varying(5),
    grimpunidad character varying(8),
    grinformacion character varying(8),
    bienes text,
    id_intervalo integer DEFAULT 5,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    ubicacion_id integer
);


--
-- Name: victima_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.victima_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_victima; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_victima (
    hijos integer,
    id_profesion integer DEFAULT 22 NOT NULL,
    id_rangoedad integer DEFAULT 6 NOT NULL,
    id_filiacion integer DEFAULT 10 NOT NULL,
    id_sectorsocial integer DEFAULT 15 NOT NULL,
    id_organizacion integer DEFAULT 16 NOT NULL,
    id_vinculoestado integer DEFAULT 38 NOT NULL,
    id_caso integer NOT NULL,
    organizacionarmada integer DEFAULT 35 NOT NULL,
    anotaciones character varying(1000),
    id_persona integer NOT NULL,
    id_etnia integer DEFAULT 1 NOT NULL,
    id_iglesia integer DEFAULT 1,
    orientacionsexual character(1) DEFAULT 'S'::bpchar NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id integer DEFAULT nextval('public.victima_seq'::regclass) NOT NULL,
    CONSTRAINT victima_hijos_check CHECK (((hijos IS NULL) OR ((hijos >= 0) AND (hijos <= 100)))),
    CONSTRAINT victima_orientacionsexual_check CHECK (((orientacionsexual = 'B'::bpchar) OR (orientacionsexual = 'G'::bpchar) OR (orientacionsexual = 'H'::bpchar) OR (orientacionsexual = 'I'::bpchar) OR (orientacionsexual = 'L'::bpchar) OR (orientacionsexual = 'O'::bpchar) OR (orientacionsexual = 'S'::bpchar) OR (orientacionsexual = 'T'::bpchar)))
);


--
-- Name: cben1; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.cben1 AS
 SELECT caso.id AS id_caso,
    subv.id_victima,
    subv.id_persona,
    1 AS npersona,
    'total'::text AS total
   FROM public.sivel2_gen_caso caso,
    public.sivel2_gen_victima victima,
    ( SELECT sivel2_gen_victima.id_persona,
            max(sivel2_gen_victima.id) AS id_victima
           FROM public.sivel2_gen_victima
          GROUP BY sivel2_gen_victima.id_persona) subv
  WHERE ((caso.fecha >= '2019-07-01'::date) AND (caso.fecha <= '2019-12-31'::date) AND (subv.id_victima = victima.id) AND (caso.id = victima.id_caso));


--
-- Name: sip_clase_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_clase_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_clase; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_clase (
    id_clalocal integer,
    id_tclase character varying(10) DEFAULT 'CP'::character varying NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    latitud double precision,
    longitud double precision,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id_municipio integer,
    id integer DEFAULT nextval('public.sip_clase_id_seq'::regclass) NOT NULL,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT clase_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sip_departamento_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_departamento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_departamento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_departamento (
    id_deplocal integer,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    latitud double precision,
    longitud double precision,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id_pais integer NOT NULL,
    id integer DEFAULT nextval('public.sip_departamento_id_seq'::regclass) NOT NULL,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT departamento_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sip_municipio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_municipio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_municipio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_municipio (
    id_munlocal integer,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    latitud double precision,
    longitud double precision,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id_departamento integer,
    id integer DEFAULT nextval('public.sip_municipio_id_seq'::regclass) NOT NULL,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT municipio_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sip_ubicacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_ubicacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_ubicacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_ubicacion (
    id integer DEFAULT nextval('public.sip_ubicacion_id_seq'::regclass) NOT NULL,
    id_tsitio integer DEFAULT 1 NOT NULL,
    id_caso integer NOT NULL,
    latitud double precision,
    longitud double precision,
    sitio character varying(500) COLLATE public.es_co_utf_8,
    lugar character varying(500) COLLATE public.es_co_utf_8,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id_pais integer,
    id_departamento integer,
    id_municipio integer,
    id_clase integer
);


--
-- Name: cben2; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.cben2 AS
 SELECT cben1.id_caso,
    cben1.id_victima,
    cben1.id_persona,
    cben1.npersona,
    cben1.total,
    ubicacion.id_departamento,
    departamento.nombre AS departamento_nombre,
    ubicacion.id_municipio,
    municipio.nombre AS municipio_nombre,
    ubicacion.id_clase,
    clase.nombre AS clase_nombre
   FROM (((((public.cben1
     JOIN public.sivel2_gen_caso caso ON ((cben1.id_caso = caso.id)))
     LEFT JOIN public.sip_ubicacion ubicacion ON ((caso.ubicacion_id = ubicacion.id)))
     LEFT JOIN public.sip_departamento departamento ON ((ubicacion.id_departamento = departamento.id)))
     LEFT JOIN public.sip_municipio municipio ON ((ubicacion.id_municipio = municipio.id)))
     LEFT JOIN public.sip_clase clase ON ((ubicacion.id_clase = clase.id)))
  GROUP BY cben1.id_caso, cben1.id_victima, cben1.id_persona, cben1.npersona, cben1.total, ubicacion.id_departamento, departamento.nombre, ubicacion.id_municipio, municipio.nombre, ubicacion.id_clase, clase.nombre;


--
-- Name: combatiente_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.combatiente_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: combatiente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.combatiente (
    id integer DEFAULT nextval('public.combatiente_seq'::regclass) NOT NULL,
    nombre character varying(100) NOT NULL,
    alias character varying(100),
    edad integer,
    sexo character(1) NOT NULL,
    id_resagresion integer NOT NULL,
    id_profesion integer,
    id_rangoedad integer,
    id_filiacion integer,
    id_sectorsocial integer,
    id_organizacion integer,
    id_vinculoestado integer,
    id_caso integer,
    organizacionarmada integer,
    CONSTRAINT combatiente_edad_check CHECK (((edad IS NULL) OR (edad >= 0))),
    CONSTRAINT combatiente_sexo_check CHECK (((sexo = 'S'::bpchar) OR (sexo = 'M'::bpchar) OR (sexo = 'F'::bpchar)))
);


--
-- Name: combatiente_presponsable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.combatiente_presponsable (
    id_p_responsable integer NOT NULL,
    id_combatiente integer NOT NULL
);


--
-- Name: sip_persona_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_persona_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_persona; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_persona (
    id integer DEFAULT nextval('public.sip_persona_id_seq'::regclass) NOT NULL,
    nombres character varying(100) NOT NULL COLLATE public.es_co_utf_8,
    apellidos character varying(100) NOT NULL COLLATE public.es_co_utf_8,
    anionac integer,
    mesnac integer,
    dianac integer,
    sexo character(1) NOT NULL,
    numerodocumento character varying(100),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id_pais integer,
    nacionalde integer,
    tdocumento_id integer,
    id_departamento integer,
    id_municipio integer,
    id_clase integer,
    CONSTRAINT persona_check CHECK (((dianac IS NULL) OR (((dianac >= 1) AND (((mesnac = 1) OR (mesnac = 3) OR (mesnac = 5) OR (mesnac = 7) OR (mesnac = 8) OR (mesnac = 10) OR (mesnac = 12)) AND (dianac <= 31))) OR (((mesnac = 4) OR (mesnac = 6) OR (mesnac = 9) OR (mesnac = 11)) AND (dianac <= 30)) OR ((mesnac = 2) AND (dianac <= 29))))),
    CONSTRAINT persona_mesnac_check CHECK (((mesnac IS NULL) OR ((mesnac >= 1) AND (mesnac <= 12)))),
    CONSTRAINT persona_sexo_check CHECK (((sexo = 'S'::bpchar) OR (sexo = 'F'::bpchar) OR (sexo = 'M'::bpchar)))
);


--
-- Name: sivel2_gen_acto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_acto (
    id_presponsable integer NOT NULL,
    id_categoria integer NOT NULL,
    id_persona integer NOT NULL,
    id_caso integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id integer DEFAULT nextval('public.acto_seq'::regclass) NOT NULL
);


--
-- Name: sivel2_gen_categoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_categoria (
    id integer NOT NULL,
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    id_pconsolidado integer,
    contadaen integer,
    tipocat character(1) DEFAULT 'I'::bpchar,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    supracategoria_id integer,
    CONSTRAINT "$3" CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion))),
    CONSTRAINT categoria_tipocat_check CHECK (((tipocat = 'I'::bpchar) OR (tipocat = 'C'::bpchar) OR (tipocat = 'O'::bpchar)))
);


--
-- Name: sivel2_gen_rangoedad_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_rangoedad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_rangoedad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_rangoedad (
    id integer DEFAULT nextval('public.sivel2_gen_rangoedad_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    limiteinferior integer DEFAULT 0 NOT NULL,
    limitesuperior integer DEFAULT 0 NOT NULL,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT rango_edad_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_supracategoria_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_supracategoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_supracategoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_supracategoria (
    codigo integer,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    id_tviolencia character varying(1) NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    id integer DEFAULT nextval('public.sivel2_gen_supracategoria_id_seq'::regclass) NOT NULL,
    CONSTRAINT supracategoria_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: cvt1; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.cvt1 AS
 SELECT DISTINCT acto.id_caso,
    acto.id_persona,
    acto.id_categoria,
    supracategoria.id_tviolencia,
    categoria.nombre AS categoria,
    rangoedad.id,
    initcap((rangoedad.nombre)::text) AS rangoedad_rango
   FROM ((((((public.sivel2_gen_acto acto
     JOIN public.sivel2_gen_caso caso ON ((acto.id_caso = caso.id)))
     JOIN public.sivel2_gen_categoria categoria ON ((acto.id_categoria = categoria.id)))
     JOIN public.sivel2_gen_supracategoria supracategoria ON ((categoria.supracategoria_id = supracategoria.id)))
     JOIN public.sivel2_gen_victima victima ON (((victima.id_persona = acto.id_persona) AND (victima.id_caso = caso.id))))
     JOIN public.sip_persona persona ON ((persona.id = acto.id_persona)))
     LEFT JOIN public.sivel2_gen_rangoedad rangoedad ON ((victima.id_rangoedad = rangoedad.id)))
  WHERE ((caso.fecha >= '2021-01-01'::date) AND (caso.fecha <= '2021-06-30'::date) AND ((supracategoria.id_tviolencia)::text = 'A'::text));


--
-- Name: fotra_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fotra_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendly_id_slugs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendly_id_slugs (
    id integer NOT NULL,
    slug character varying NOT NULL,
    sluggable_id integer NOT NULL,
    sluggable_type character varying(50),
    scope character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.friendly_id_slugs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: friendly_id_slugs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.friendly_id_slugs_id_seq OWNED BY public.friendly_id_slugs.id;


--
-- Name: heb412_gen_campohc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_campohc (
    id integer NOT NULL,
    doc_id integer NOT NULL,
    nombrecampo character varying(127) NOT NULL,
    columna character varying(5) NOT NULL,
    fila integer
);


--
-- Name: heb412_gen_campohc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_campohc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_campohc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_campohc_id_seq OWNED BY public.heb412_gen_campohc.id;


--
-- Name: heb412_gen_campoplantillahcm; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_campoplantillahcm (
    id integer NOT NULL,
    plantillahcm_id integer,
    nombrecampo character varying(183),
    columna character varying(5)
);


--
-- Name: heb412_gen_campoplantillahcm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_campoplantillahcm_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_campoplantillahcm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_campoplantillahcm_id_seq OWNED BY public.heb412_gen_campoplantillahcm.id;


--
-- Name: heb412_gen_campoplantillahcr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_campoplantillahcr (
    id bigint NOT NULL,
    plantillahcr_id integer,
    nombrecampo character varying(127),
    columna character varying(5),
    fila integer
);


--
-- Name: heb412_gen_campoplantillahcr_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_campoplantillahcr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_campoplantillahcr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_campoplantillahcr_id_seq OWNED BY public.heb412_gen_campoplantillahcr.id;


--
-- Name: heb412_gen_carpetaexclusiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_carpetaexclusiva (
    id bigint NOT NULL,
    carpeta character varying(2048),
    grupo_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: heb412_gen_carpetaexclusiva_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_carpetaexclusiva_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_carpetaexclusiva_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_carpetaexclusiva_id_seq OWNED BY public.heb412_gen_carpetaexclusiva.id;


--
-- Name: heb412_gen_doc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_doc (
    id integer NOT NULL,
    nombre character varying(512),
    tipodoc character varying(1),
    dirpapa integer,
    url character varying(1024),
    fuente character varying(1024),
    descripcion character varying(5000),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    adjunto_file_name character varying,
    adjunto_content_type character varying,
    adjunto_file_size bigint,
    adjunto_updated_at timestamp without time zone,
    nombremenu character varying(127),
    vista character varying(255),
    filainicial integer,
    ruta character varying(2047),
    licencia character varying(255),
    tdoc_id integer,
    tdoc_type character varying
);


--
-- Name: heb412_gen_doc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_doc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_doc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_doc_id_seq OWNED BY public.heb412_gen_doc.id;


--
-- Name: heb412_gen_formulario_plantillahcm; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_formulario_plantillahcm (
    formulario_id integer,
    plantillahcm_id integer
);


--
-- Name: heb412_gen_formulario_plantillahcr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_formulario_plantillahcr (
    id bigint NOT NULL,
    plantillahcr_id integer,
    formulario_id integer
);


--
-- Name: heb412_gen_formulario_plantillahcr_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_formulario_plantillahcr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_formulario_plantillahcr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_formulario_plantillahcr_id_seq OWNED BY public.heb412_gen_formulario_plantillahcr.id;


--
-- Name: heb412_gen_plantilladoc; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_plantilladoc (
    id bigint NOT NULL,
    ruta character varying(2047),
    fuente character varying(1023),
    licencia character varying(1023),
    vista character varying(127),
    nombremenu character varying(127)
);


--
-- Name: heb412_gen_plantilladoc_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_plantilladoc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_plantilladoc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_plantilladoc_id_seq OWNED BY public.heb412_gen_plantilladoc.id;


--
-- Name: heb412_gen_plantillahcm; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_plantillahcm (
    id integer NOT NULL,
    ruta character varying(2047) NOT NULL,
    fuente character varying(1023),
    licencia character varying(1023),
    vista character varying(127) NOT NULL,
    nombremenu character varying(127) NOT NULL,
    filainicial integer NOT NULL
);


--
-- Name: heb412_gen_plantillahcm_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_plantillahcm_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_plantillahcm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_plantillahcm_id_seq OWNED BY public.heb412_gen_plantillahcm.id;


--
-- Name: heb412_gen_plantillahcr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.heb412_gen_plantillahcr (
    id bigint NOT NULL,
    ruta character varying(2047),
    fuente character varying(1023),
    licencia character varying(1023),
    vista character varying(127),
    nombremenu character varying(127)
);


--
-- Name: heb412_gen_plantillahcr_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.heb412_gen_plantillahcr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: heb412_gen_plantillahcr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.heb412_gen_plantillahcr_id_seq OWNED BY public.heb412_gen_plantillahcr.id;


--
-- Name: homonimosim_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.homonimosim_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_caso_usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_usuario (
    id_usuario integer NOT NULL,
    id_caso integer NOT NULL,
    fechainicio date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: iniciador; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.iniciador AS
 SELECT sivel2_gen_caso_usuario.id_caso,
    sivel2_gen_caso_usuario.fechainicio AS fecha_inicio,
    min(sivel2_gen_caso_usuario.id_usuario) AS id_funcionario
   FROM public.sivel2_gen_caso_usuario,
    ( SELECT funcionario_caso_1.id_caso,
            min(funcionario_caso_1.fechainicio) AS m
           FROM public.sivel2_gen_caso_usuario funcionario_caso_1
          GROUP BY funcionario_caso_1.id_caso) c
  WHERE ((sivel2_gen_caso_usuario.id_caso = c.id_caso) AND (sivel2_gen_caso_usuario.fechainicio = c.m))
  GROUP BY sivel2_gen_caso_usuario.id_caso, sivel2_gen_caso_usuario.fechainicio
  ORDER BY sivel2_gen_caso_usuario.id_caso, sivel2_gen_caso_usuario.fechainicio;


--
-- Name: mr519_gen_campo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mr519_gen_campo (
    id bigint NOT NULL,
    nombre character varying(512) NOT NULL,
    ayudauso character varying(1024),
    tipo integer DEFAULT 1 NOT NULL,
    obligatorio boolean,
    formulario_id integer NOT NULL,
    nombreinterno character varying(60),
    fila integer,
    columna integer,
    ancho integer,
    tablabasica character varying(32)
);


--
-- Name: mr519_gen_campo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mr519_gen_campo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mr519_gen_campo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mr519_gen_campo_id_seq OWNED BY public.mr519_gen_campo.id;


--
-- Name: mr519_gen_encuestapersona; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mr519_gen_encuestapersona (
    id bigint NOT NULL,
    persona_id integer,
    formulario_id integer,
    fecha date,
    fechainicio date NOT NULL,
    fechafin date,
    adurl character varying(32),
    respuestafor_id integer
);


--
-- Name: mr519_gen_encuestapersona_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mr519_gen_encuestapersona_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mr519_gen_encuestapersona_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mr519_gen_encuestapersona_id_seq OWNED BY public.mr519_gen_encuestapersona.id;


--
-- Name: mr519_gen_encuestausuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mr519_gen_encuestausuario (
    id bigint NOT NULL,
    usuario_id integer NOT NULL,
    fecha date,
    fechainicio date NOT NULL,
    fechafin date,
    respuestafor_id integer
);


--
-- Name: mr519_gen_encuestausuario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mr519_gen_encuestausuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mr519_gen_encuestausuario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mr519_gen_encuestausuario_id_seq OWNED BY public.mr519_gen_encuestausuario.id;


--
-- Name: mr519_gen_formulario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mr519_gen_formulario (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    nombreinterno character varying(60)
);


--
-- Name: mr519_gen_formulario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mr519_gen_formulario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mr519_gen_formulario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mr519_gen_formulario_id_seq OWNED BY public.mr519_gen_formulario.id;


--
-- Name: mr519_gen_opcioncs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mr519_gen_opcioncs (
    id bigint NOT NULL,
    campo_id integer NOT NULL,
    nombre character varying(1024) NOT NULL,
    valor character varying(60) NOT NULL
);


--
-- Name: mr519_gen_opcioncs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mr519_gen_opcioncs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mr519_gen_opcioncs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mr519_gen_opcioncs_id_seq OWNED BY public.mr519_gen_opcioncs.id;


--
-- Name: mr519_gen_planencuesta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mr519_gen_planencuesta (
    id bigint NOT NULL,
    fechaini date,
    fechafin date,
    formulario_id integer,
    plantillacorreoinv_id integer,
    adurl character varying(32),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: mr519_gen_planencuesta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mr519_gen_planencuesta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mr519_gen_planencuesta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mr519_gen_planencuesta_id_seq OWNED BY public.mr519_gen_planencuesta.id;


--
-- Name: mr519_gen_respuestafor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mr519_gen_respuestafor (
    id bigint NOT NULL,
    formulario_id integer,
    fechaini date NOT NULL,
    fechacambio date NOT NULL
);


--
-- Name: mr519_gen_respuestafor_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mr519_gen_respuestafor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mr519_gen_respuestafor_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mr519_gen_respuestafor_id_seq OWNED BY public.mr519_gen_respuestafor.id;


--
-- Name: mr519_gen_valorcampo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mr519_gen_valorcampo (
    id bigint NOT NULL,
    campo_id integer NOT NULL,
    valor character varying(5000),
    respuestafor_id integer NOT NULL,
    valorjson json
);


--
-- Name: mr519_gen_valorcampo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mr519_gen_valorcampo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mr519_gen_valorcampo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mr519_gen_valorcampo_id_seq OWNED BY public.mr519_gen_valorcampo.id;


--
-- Name: napellidos; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.napellidos AS
 SELECT s.apellido,
    count(*) AS frec
   FROM ( SELECT public.divarr(string_to_array(btrim((sip_persona.apellidos)::text), ' '::text)) AS apellido
           FROM public.sip_persona,
            public.sivel2_gen_victima
          WHERE (sivel2_gen_victima.id_persona = sip_persona.id)) s
  GROUP BY s.apellido
  ORDER BY (count(*))
  WITH NO DATA;


--
-- Name: nhombres; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.nhombres AS
 SELECT s.nombre,
    count(*) AS frec
   FROM ( SELECT public.divarr(string_to_array(btrim((sip_persona.nombres)::text), ' '::text)) AS nombre
           FROM public.sip_persona,
            public.sivel2_gen_victima
          WHERE ((sivel2_gen_victima.id_persona = sip_persona.id) AND (sip_persona.sexo = 'M'::bpchar))) s
  GROUP BY s.nombre
  ORDER BY (count(*))
  WITH NO DATA;


--
-- Name: nmujeres; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.nmujeres AS
 SELECT s.nombre,
    count(*) AS frec
   FROM ( SELECT public.divarr(string_to_array(btrim((sip_persona.nombres)::text), ' '::text)) AS nombre
           FROM public.sip_persona,
            public.sivel2_gen_victima
          WHERE ((sivel2_gen_victima.id_persona = sip_persona.id) AND (sip_persona.sexo = 'F'::bpchar))) s
  GROUP BY s.nombre
  ORDER BY (count(*))
  WITH NO DATA;


--
-- Name: paypal_commerce_platform_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paypal_commerce_platform_sources (
    id bigint NOT NULL,
    payment_method_id integer,
    authorization_id character varying,
    capture_id character varying,
    paypal_email character varying,
    paypal_order_id character varying,
    refund_id character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: paypal_commerce_platform_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.paypal_commerce_platform_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: paypal_commerce_platform_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.paypal_commerce_platform_sources_id_seq OWNED BY public.paypal_commerce_platform_sources.id;


--
-- Name: persona_nomap; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.persona_nomap AS
 SELECT sip_persona.id,
    upper(btrim(((btrim((sip_persona.nombres)::text) || ' '::text) || btrim((sip_persona.apellidos)::text)))) AS nomap
   FROM public.sip_persona
  WITH NO DATA;


--
-- Name: primerusuario; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.primerusuario AS
 SELECT sivel2_gen_caso_usuario.id_caso,
    min(sivel2_gen_caso_usuario.fechainicio) AS fechainicio,
    public.first(sivel2_gen_caso_usuario.id_usuario) AS id_usuario
   FROM public.sivel2_gen_caso_usuario
  GROUP BY sivel2_gen_caso_usuario.id_caso
  ORDER BY sivel2_gen_caso_usuario.id_caso;


--
-- Name: resagresion_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resagresion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sip_anexo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_anexo (
    id integer NOT NULL,
    descripcion character varying(1500) NOT NULL COLLATE public.es_co_utf_8,
    adjunto_file_name character varying(255),
    adjunto_content_type character varying(255),
    adjunto_file_size integer,
    adjunto_updated_at timestamp without time zone,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sip_anexo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_anexo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_anexo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_anexo_id_seq OWNED BY public.sip_anexo.id;


--
-- Name: sip_bitacora; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_bitacora (
    id bigint NOT NULL,
    fecha timestamp without time zone NOT NULL,
    ip character varying(100),
    usuario_id integer,
    url character varying(1023),
    params character varying(5000),
    modelo character varying(511),
    modelo_id integer,
    operacion character varying(63),
    detalle json,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sip_bitacora_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_bitacora_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_bitacora_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_bitacora_id_seq OWNED BY public.sip_bitacora.id;


--
-- Name: sip_etiqueta_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_etiqueta_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_etiqueta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_etiqueta (
    id integer DEFAULT nextval('public.sip_etiqueta_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    observaciones character varying(5000) NOT NULL COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    CONSTRAINT etiqueta_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sip_etiqueta_municipio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_etiqueta_municipio (
    etiqueta_id bigint NOT NULL,
    municipio_id bigint NOT NULL
);


--
-- Name: sip_fuenteprensa_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_fuenteprensa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_fuenteprensa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_fuenteprensa (
    id integer DEFAULT nextval('public.sip_fuenteprensa_id_seq'::regclass) NOT NULL,
    tfuente character varying(25),
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT sip_fuenteprensa_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sip_grupo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_grupo (
    id integer NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sip_grupo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_grupo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_grupo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_grupo_id_seq OWNED BY public.sip_grupo.id;


--
-- Name: sip_grupo_usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_grupo_usuario (
    usuario_id integer NOT NULL,
    sip_grupo_id integer NOT NULL
);


--
-- Name: sip_grupoper_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_grupoper_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_grupoper; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_grupoper (
    id integer DEFAULT nextval('public.sip_grupoper_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    anotaciones character varying(1000),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sip_mundep_sinorden; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.sip_mundep_sinorden AS
 SELECT ((sip_departamento.id_deplocal * 1000) + sip_municipio.id_munlocal) AS idlocal,
    (((sip_municipio.nombre)::text || ' / '::text) || (sip_departamento.nombre)::text) AS nombre
   FROM (public.sip_municipio
     JOIN public.sip_departamento ON ((sip_municipio.id_departamento = sip_departamento.id)))
  WHERE ((sip_departamento.id_pais = 170) AND (sip_municipio.fechadeshabilitacion IS NULL) AND (sip_departamento.fechadeshabilitacion IS NULL))
UNION
 SELECT sip_departamento.id_deplocal AS idlocal,
    sip_departamento.nombre
   FROM public.sip_departamento
  WHERE ((sip_departamento.id_pais = 170) AND (sip_departamento.fechadeshabilitacion IS NULL));


--
-- Name: sip_mundep; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.sip_mundep AS
 SELECT sip_mundep_sinorden.idlocal,
    sip_mundep_sinorden.nombre,
    to_tsvector('spanish'::regconfig, public.unaccent(sip_mundep_sinorden.nombre)) AS mundep
   FROM public.sip_mundep_sinorden
  ORDER BY (sip_mundep_sinorden.nombre COLLATE public.es_co_utf_8)
  WITH NO DATA;


--
-- Name: sip_oficina; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_oficina (
    id integer NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT CURRENT_DATE,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8
);


--
-- Name: sip_oficina_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_oficina_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_oficina_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_oficina_id_seq OWNED BY public.sip_oficina.id;


--
-- Name: sip_orgsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_orgsocial (
    id bigint NOT NULL,
    grupoper_id integer NOT NULL,
    telefono character varying(500),
    fax character varying(500),
    direccion character varying(500),
    pais_id integer,
    web character varying(500),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    fechadeshabilitacion date
);


--
-- Name: sip_orgsocial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_orgsocial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_orgsocial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_orgsocial_id_seq OWNED BY public.sip_orgsocial.id;


--
-- Name: sip_orgsocial_persona; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_orgsocial_persona (
    id bigint NOT NULL,
    persona_id integer NOT NULL,
    orgsocial_id integer,
    perfilorgsocial_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    correo character varying(100),
    cargo character varying(254)
);


--
-- Name: sip_orgsocial_persona_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_orgsocial_persona_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_orgsocial_persona_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_orgsocial_persona_id_seq OWNED BY public.sip_orgsocial_persona.id;


--
-- Name: sip_orgsocial_sectororgsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_orgsocial_sectororgsocial (
    orgsocial_id integer,
    sectororgsocial_id integer
);


--
-- Name: sip_pais; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_pais (
    id integer NOT NULL,
    nombre character varying(200) COLLATE public.es_co_utf_8,
    nombreiso character varying(200),
    latitud double precision,
    longitud double precision,
    alfa2 character varying(2),
    alfa3 character varying(3),
    codiso integer,
    div1 character varying(100),
    div2 character varying(100),
    div3 character varying(100),
    fechacreacion date,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8
);


--
-- Name: sip_pais_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_pais_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_pais_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_pais_id_seq OWNED BY public.sip_pais.id;


--
-- Name: sip_perfilorgsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_perfilorgsocial (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sip_perfilorgsocial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_perfilorgsocial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_perfilorgsocial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_perfilorgsocial_id_seq OWNED BY public.sip_perfilorgsocial.id;


--
-- Name: sip_persona_trelacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_persona_trelacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_persona_trelacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_persona_trelacion (
    persona1 integer NOT NULL,
    persona2 integer NOT NULL,
    id_trelacion character(2) DEFAULT 'SI'::bpchar NOT NULL,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id integer DEFAULT nextval('public.sip_persona_trelacion_id_seq'::regclass) NOT NULL
);


--
-- Name: sip_sectororgsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_sectororgsocial (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sip_sectororgsocial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_sectororgsocial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_sectororgsocial_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_sectororgsocial_id_seq OWNED BY public.sip_sectororgsocial.id;


--
-- Name: sip_tclase; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_tclase (
    id character varying(10) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT tipo_clase_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sip_tdocumento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_tdocumento (
    id integer NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    sigla character varying(100),
    formatoregex character varying(500),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8
);


--
-- Name: sip_tdocumento_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_tdocumento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_tdocumento_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_tdocumento_id_seq OWNED BY public.sip_tdocumento.id;


--
-- Name: sip_tema; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_tema (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    nav_ini character varying(8),
    nav_fin character varying(8),
    nav_fuente character varying(8),
    fondo_lista character varying(8),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    btn_primario_fondo_ini character varying(127),
    btn_primario_fondo_fin character varying(127),
    btn_primario_fuente character varying(127),
    btn_peligro_fondo_ini character varying(127),
    btn_peligro_fondo_fin character varying(127),
    btn_peligro_fuente character varying(127),
    btn_accion_fondo_ini character varying(127),
    btn_accion_fondo_fin character varying(127),
    btn_accion_fuente character varying(127),
    alerta_exito_fondo character varying(127),
    alerta_exito_fuente character varying(127),
    alerta_problema_fondo character varying(127),
    alerta_problema_fuente character varying(127),
    fondo character varying(127),
    color_fuente character varying(127),
    color_flota_subitem_fuente character varying,
    color_flota_subitem_fondo character varying
);


--
-- Name: sip_tema_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_tema_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_tema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_tema_id_seq OWNED BY public.sip_tema.id;


--
-- Name: sip_trelacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_trelacion (
    id character(2) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    inverso character varying(2),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    CONSTRAINT tipo_relacion_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sip_trivalente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_trivalente (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sip_trivalente_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_trivalente_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_trivalente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_trivalente_id_seq OWNED BY public.sip_trivalente.id;


--
-- Name: sip_tsitio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_tsitio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_tsitio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_tsitio (
    id integer DEFAULT nextval('public.sip_tsitio_id_seq'::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000) COLLATE public.es_co_utf_8,
    CONSTRAINT tipo_sitio_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sip_ubicacionpre; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sip_ubicacionpre (
    id bigint NOT NULL,
    nombre character varying(2000) NOT NULL COLLATE public.es_co_utf_8,
    pais_id integer,
    departamento_id integer,
    municipio_id integer,
    clase_id integer,
    lugar character varying(500),
    sitio character varying(500),
    tsitio_id integer,
    latitud double precision,
    longitud double precision,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    nombre_sin_pais character varying(500)
);


--
-- Name: sip_ubicacionpre_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sip_ubicacionpre_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sip_ubicacionpre_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sip_ubicacionpre_id_seq OWNED BY public.sip_ubicacionpre.id;


--
-- Name: sivel2_gen_actividadoficio; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_actividadoficio (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sivel2_gen_actividadoficio_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_actividadoficio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_actividadoficio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sivel2_gen_actividadoficio_id_seq OWNED BY public.sivel2_gen_actividadoficio.id;


--
-- Name: sivel2_gen_actocolectivo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_actocolectivo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_actocolectivo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_actocolectivo (
    id_presponsable integer NOT NULL,
    id_categoria integer NOT NULL,
    id_grupoper integer NOT NULL,
    id_caso integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id integer DEFAULT nextval('public.sivel2_gen_actocolectivo_id_seq'::regclass) NOT NULL
);


--
-- Name: sivel2_gen_anexo_caso_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_anexo_caso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_anexo_caso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_anexo_caso (
    id integer DEFAULT nextval('public.sivel2_gen_anexo_caso_id_seq'::regclass) NOT NULL,
    id_caso integer NOT NULL,
    fecha date NOT NULL,
    fechaffrecuente date,
    fuenteprensa_id integer,
    id_fotra integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id_anexo integer NOT NULL
);


--
-- Name: sivel2_gen_antecedente_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_antecedente_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_antecedente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_antecedente (
    id integer DEFAULT nextval('public.sivel2_gen_antecedente_id_seq'::regclass) NOT NULL,
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT "$1" CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion > fechacreacion)))
);


--
-- Name: sivel2_gen_antecedente_caso; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_antecedente_caso (
    id_antecedente integer NOT NULL,
    id_caso integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sivel2_gen_antecedente_combatiente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_antecedente_combatiente (
    id_antecedente integer,
    id_combatiente integer
);


--
-- Name: sivel2_gen_antecedente_victima; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_antecedente_victima (
    id_antecedente integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id_victima integer
);


--
-- Name: sivel2_gen_antecedente_victimacolectiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_antecedente_victimacolectiva (
    id_antecedente integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    victimacolectiva_id integer
);


--
-- Name: sivel2_gen_caso_categoria_presponsable_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_caso_categoria_presponsable_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_caso_categoria_presponsable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_categoria_presponsable (
    id_categoria integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id_caso_presponsable integer,
    id integer DEFAULT nextval('public.sivel2_gen_caso_categoria_presponsable_id_seq'::regclass) NOT NULL
);


--
-- Name: sivel2_gen_caso_contexto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_contexto (
    id_caso integer NOT NULL,
    id_contexto integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sivel2_gen_caso_etiqueta; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_etiqueta (
    id_caso integer NOT NULL,
    id_etiqueta integer NOT NULL,
    id_usuario integer NOT NULL,
    fecha date NOT NULL,
    observaciones character varying(5000),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id integer DEFAULT nextval('public.caso_etiqueta_seq'::regclass) NOT NULL
);


--
-- Name: sivel2_gen_caso_fotra_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_caso_fotra_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_caso_fotra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_fotra (
    id_caso integer NOT NULL,
    id_fotra integer,
    anotacion character varying(1024),
    fecha date NOT NULL,
    ubicacionfisica character varying(1024),
    tfuente character varying(25),
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    id integer DEFAULT nextval('public.sivel2_gen_caso_fotra_seq'::regclass) NOT NULL,
    anexo_caso_id integer
);


--
-- Name: sivel2_gen_caso_frontera; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_frontera (
    id_frontera integer NOT NULL,
    id_caso integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sivel2_gen_caso_fuenteprensa_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_caso_fuenteprensa_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_caso_fuenteprensa; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_fuenteprensa (
    fecha date NOT NULL,
    ubicacion character varying(1024),
    clasificacion character varying(100),
    ubicacionfisica character varying(1024),
    fuenteprensa_id integer NOT NULL,
    id_caso integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id integer DEFAULT nextval('public.sivel2_gen_caso_fuenteprensa_seq'::regclass) NOT NULL,
    anexo_caso_id integer
);


--
-- Name: sivel2_gen_caso_presponsable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_presponsable (
    id_caso integer NOT NULL,
    id_presponsable integer NOT NULL,
    tipo integer DEFAULT 0 NOT NULL,
    bloque character varying(50),
    frente character varying(50),
    brigada character varying(50),
    batallon character varying(50),
    division character varying(50),
    id integer DEFAULT nextval('public.caso_presponsable_seq'::regclass) NOT NULL,
    otro character varying(500),
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sivel2_gen_caso_region; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_region (
    id_region integer NOT NULL,
    id_caso integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sivel2_gen_caso_respuestafor; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_caso_respuestafor (
    caso_id bigint NOT NULL,
    respuestafor_id bigint NOT NULL
);


--
-- Name: sivel2_gen_combatiente; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_combatiente (
    id integer NOT NULL,
    nombre character varying(500) NOT NULL,
    alias character varying(500),
    edad integer,
    sexo character varying(1) DEFAULT 'S'::character varying NOT NULL,
    id_resagresion integer DEFAULT 1 NOT NULL,
    id_profesion integer DEFAULT 22,
    id_rangoedad integer DEFAULT 6,
    id_filiacion integer DEFAULT 10,
    id_sectorsocial integer DEFAULT 15,
    id_organizacion integer DEFAULT 16,
    id_vinculoestado integer DEFAULT 38,
    id_caso integer,
    organizacionarmada integer DEFAULT 35,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sivel2_gen_combatiente_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_combatiente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_combatiente_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sivel2_gen_combatiente_id_seq OWNED BY public.sivel2_gen_combatiente.id;


--
-- Name: sivel2_gen_presponsable_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_presponsable_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_presponsable; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_presponsable (
    id integer DEFAULT nextval('public.sivel2_gen_presponsable_id_seq'::regclass) NOT NULL,
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    papa_id integer,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT presuntos_responsables_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_conscaso1; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.sivel2_gen_conscaso1 AS
 SELECT caso.id AS caso_id,
    caso.fecha,
    caso.memo,
    array_to_string(ARRAY( SELECT (((COALESCE(departamento.nombre, ''::character varying))::text || ' / '::text) || (COALESCE(municipio.nombre, ''::character varying))::text)
           FROM ((public.sip_ubicacion ubicacion
             LEFT JOIN public.sip_departamento departamento ON ((ubicacion.id_departamento = departamento.id)))
             LEFT JOIN public.sip_municipio municipio ON ((ubicacion.id_municipio = municipio.id)))
          WHERE (ubicacion.id_caso = caso.id)), ', '::text) AS ubicaciones,
    array_to_string(ARRAY( SELECT (((persona.nombres)::text || ' '::text) || (persona.apellidos)::text)
           FROM public.sip_persona persona,
            public.sivel2_gen_victima victima
          WHERE ((persona.id = victima.id_persona) AND (victima.id_caso = caso.id))), ', '::text) AS victimas,
    array_to_string(ARRAY( SELECT presponsable.nombre
           FROM public.sivel2_gen_presponsable presponsable,
            public.sivel2_gen_caso_presponsable caso_presponsable
          WHERE ((presponsable.id = caso_presponsable.id_presponsable) AND (caso_presponsable.id_caso = caso.id))), ', '::text) AS presponsables,
    array_to_string(ARRAY( SELECT (((((((supracategoria.id_tviolencia)::text || ':'::text) || categoria.supracategoria_id) || ':'::text) || categoria.id) || ' '::text) || (categoria.nombre)::text)
           FROM public.sivel2_gen_categoria categoria,
            public.sivel2_gen_supracategoria supracategoria,
            public.sivel2_gen_acto acto
          WHERE ((categoria.id = acto.id_categoria) AND (supracategoria.id = categoria.supracategoria_id) AND (acto.id_caso = caso.id))), ', '::text) AS tipificacion
   FROM public.sivel2_gen_caso caso;


--
-- Name: sivel2_gen_conscaso; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.sivel2_gen_conscaso AS
 SELECT sivel2_gen_conscaso1.caso_id,
    sivel2_gen_conscaso1.fecha,
    sivel2_gen_conscaso1.memo,
    sivel2_gen_conscaso1.ubicaciones,
    sivel2_gen_conscaso1.victimas,
    sivel2_gen_conscaso1.presponsables,
    sivel2_gen_conscaso1.tipificacion,
    now() AS ultimo_refresco,
    to_tsvector('spanish'::regconfig, public.unaccent(((((((((((((sivel2_gen_conscaso1.caso_id || ' '::text) || replace(((sivel2_gen_conscaso1.fecha)::character varying)::text, '-'::text, ' '::text)) || ' '::text) || sivel2_gen_conscaso1.memo) || ' '::text) || sivel2_gen_conscaso1.ubicaciones) || ' '::text) || sivel2_gen_conscaso1.victimas) || ' '::text) || sivel2_gen_conscaso1.presponsables) || ' '::text) || sivel2_gen_conscaso1.tipificacion))) AS q
   FROM public.sivel2_gen_conscaso1
  WITH NO DATA;


--
-- Name: sivel2_gen_consexpcaso; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.sivel2_gen_consexpcaso AS
 SELECT conscaso.caso_id,
    conscaso.fecha,
    conscaso.memo,
    conscaso.ubicaciones,
    conscaso.victimas,
    conscaso.presponsables,
    conscaso.tipificacion,
    conscaso.ultimo_refresco,
    conscaso.q,
    caso.titulo,
    caso.hora,
    caso.duracion,
    caso.grconfiabilidad,
    caso.gresclarecimiento,
    caso.grimpunidad,
    caso.grinformacion,
    caso.bienes,
    caso.id_intervalo,
    caso.created_at,
    caso.updated_at
   FROM (public.sivel2_gen_conscaso conscaso
     JOIN public.sivel2_gen_caso caso ON ((caso.id = conscaso.caso_id)))
  WHERE (conscaso.caso_id IN ( SELECT sivel2_gen_conscaso.caso_id
           FROM public.sivel2_gen_conscaso
          WHERE ((sivel2_gen_conscaso.caso_id IN ( SELECT sivel2_gen_caso.id
                   FROM public.sivel2_gen_caso)) AND (sivel2_gen_conscaso.fecha >= '2019-07-01'::date) AND (sivel2_gen_conscaso.fecha <= '2019-12-31'::date) AND (sivel2_gen_conscaso.caso_id IN ( SELECT sivel2_gen_caso_presponsable.id_caso
                   FROM public.sivel2_gen_caso_presponsable
                  WHERE (sivel2_gen_caso_presponsable.id_presponsable = 7))))
          ORDER BY sivel2_gen_conscaso.fecha, sivel2_gen_conscaso.caso_id))
  ORDER BY conscaso.fecha, conscaso.caso_id
  WITH NO DATA;


--
-- Name: sivel2_gen_contexto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_contexto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_contexto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_contexto (
    id integer DEFAULT nextval('public.sivel2_gen_contexto_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT contexto_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_contextovictima; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_contextovictima (
    id bigint NOT NULL,
    nombre character varying(100) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sivel2_gen_contextovictima_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_contextovictima_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_contextovictima_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sivel2_gen_contextovictima_id_seq OWNED BY public.sivel2_gen_contextovictima.id;


--
-- Name: sivel2_gen_contextovictima_victima; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_contextovictima_victima (
    contextovictima_id integer,
    victima_id integer
);


--
-- Name: sivel2_gen_departamento_region; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_departamento_region (
    departamento_id integer,
    region_id integer
);


--
-- Name: sivel2_gen_escolaridad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_escolaridad (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sivel2_gen_escolaridad_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_escolaridad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_escolaridad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sivel2_gen_escolaridad_id_seq OWNED BY public.sivel2_gen_escolaridad.id;


--
-- Name: sivel2_gen_estadocivil; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_estadocivil (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sivel2_gen_estadocivil_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_estadocivil_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_estadocivil_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sivel2_gen_estadocivil_id_seq OWNED BY public.sivel2_gen_estadocivil.id;


--
-- Name: sivel2_gen_etnia_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_etnia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_etnia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_etnia (
    id integer DEFAULT nextval('public.sivel2_gen_etnia_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    descripcion character varying(1000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT etnia_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_etnia_victimacolectiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_etnia_victimacolectiva (
    etnia_id integer,
    victimacolectiva_id integer
);


--
-- Name: sivel2_gen_filiacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_filiacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_filiacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_filiacion (
    id integer DEFAULT nextval('public.sivel2_gen_filiacion_id_seq'::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT filiacion_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_filiacion_victimacolectiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_filiacion_victimacolectiva (
    id_filiacion integer DEFAULT 10 NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    victimacolectiva_id integer
);


--
-- Name: sivel2_gen_fotra; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_fotra (
    id integer DEFAULT nextval(('fuente_directa_seq'::text)::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: sivel2_gen_frontera_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_frontera_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_frontera; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_frontera (
    id integer DEFAULT nextval('public.sivel2_gen_frontera_id_seq'::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT frontera_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_iglesia_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_iglesia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_iglesia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_iglesia (
    id integer DEFAULT nextval('public.sivel2_gen_iglesia_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    descripcion character varying(1000),
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT iglesia_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario (
    nusuario character varying(15) NOT NULL,
    nombre character varying(50) COLLATE public.es_co_utf_8,
    descripcion character varying(50),
    rol integer DEFAULT 4,
    password character varying(64) DEFAULT ''::character varying,
    idioma character varying(6) DEFAULT 'es_CO'::character varying NOT NULL,
    id integer DEFAULT nextval('public.usuario_id_seq'::regclass) NOT NULL,
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    email character varying(255) DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying(255) DEFAULT ''::character varying NOT NULL,
    sign_in_count integer DEFAULT 0 NOT NULL,
    failed_attempts integer,
    unlock_token character varying(64),
    locked_at timestamp without time zone,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying,
    last_sign_in_ip character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    oficina_id integer,
    tema_id integer,
    observadorffechaini date,
    observadorffechafin date,
    spree_api_key character varying(48),
    ship_address_id integer,
    bill_address_id integer,
    CONSTRAINT usuario_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion))),
    CONSTRAINT usuario_rol_check CHECK ((rol >= 1))
);


--
-- Name: sivel2_gen_iniciador; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.sivel2_gen_iniciador AS
 SELECT s3.id_caso,
    s3.fechainicio,
    s3.id_usuario,
    usuario.nusuario
   FROM public.usuario,
    ( SELECT s2.id_caso,
            s2.fechainicio,
            min(s2.id_usuario) AS id_usuario
           FROM public.sivel2_gen_caso_usuario s2,
            ( SELECT f1.id_caso,
                    min(f1.fechainicio) AS m
                   FROM public.sivel2_gen_caso_usuario f1
                  GROUP BY f1.id_caso) c
          WHERE ((s2.id_caso = c.id_caso) AND (s2.fechainicio = c.m))
          GROUP BY s2.id_caso, s2.fechainicio
          ORDER BY s2.id_caso, s2.fechainicio) s3
  WHERE (usuario.id = s3.id_usuario);


--
-- Name: sivel2_gen_intervalo_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_intervalo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_intervalo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_intervalo (
    id integer DEFAULT nextval('public.sivel2_gen_intervalo_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    rango character varying(25) NOT NULL,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT intervalo_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_maternidad; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_maternidad (
    id bigint NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sivel2_gen_maternidad_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_maternidad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_maternidad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sivel2_gen_maternidad_id_seq OWNED BY public.sivel2_gen_maternidad.id;


--
-- Name: sivel2_gen_municipio_region; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_municipio_region (
    municipio_id integer,
    region_id integer
);


--
-- Name: sivel2_gen_observador_filtrodepartamento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_observador_filtrodepartamento (
    usuario_id integer,
    departamento_id integer
);


--
-- Name: sivel2_gen_organizacion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_organizacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_organizacion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_organizacion (
    id integer DEFAULT nextval('public.sivel2_gen_organizacion_id_seq'::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT organizacion_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_organizacion_victimacolectiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_organizacion_victimacolectiva (
    id_organizacion integer DEFAULT 16 NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    victimacolectiva_id integer
);


--
-- Name: sivel2_gen_pconsolidado_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_pconsolidado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_pconsolidado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_pconsolidado (
    id integer DEFAULT nextval('public.sivel2_gen_pconsolidado_id_seq'::regclass) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    tipoviolencia character varying(25) NOT NULL,
    clasificacion character varying(25) NOT NULL,
    peso integer DEFAULT 0,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(500),
    CONSTRAINT parametros_reporte_consolidado_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_profesion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_profesion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_profesion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_profesion (
    id integer DEFAULT nextval('public.sivel2_gen_profesion_id_seq'::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT CURRENT_DATE NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT profesion_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_profesion_victimacolectiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_profesion_victimacolectiva (
    id_profesion integer DEFAULT 22 NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    victimacolectiva_id integer
);


--
-- Name: sivel2_gen_rangoedad_victimacolectiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_rangoedad_victimacolectiva (
    id_rangoedad integer DEFAULT 6 NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    victimacolectiva_id integer
);


--
-- Name: sivel2_gen_region_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_region_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_region; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_region (
    id integer DEFAULT nextval('public.sivel2_gen_region_id_seq'::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT region_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_resagresion; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_resagresion (
    id integer NOT NULL,
    nombre character varying(500) NOT NULL,
    observaciones character varying(5000),
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: sivel2_gen_resagresion_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_resagresion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_resagresion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sivel2_gen_resagresion_id_seq OWNED BY public.sivel2_gen_resagresion.id;


--
-- Name: sivel2_gen_sectorsocial_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_sectorsocial_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_sectorsocial; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_sectorsocial (
    id integer DEFAULT nextval('public.sivel2_gen_sectorsocial_id_seq'::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT sector_social_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_sectorsocial_victimacolectiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_sectorsocial_victimacolectiva (
    id_sectorsocial integer DEFAULT 15 NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    victimacolectiva_id integer
);


--
-- Name: sivel2_gen_sectorsocialsec_victima; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_sectorsocialsec_victima (
    sectorsocial_id integer,
    victima_id integer
);


--
-- Name: sivel2_gen_tviolencia; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_tviolencia (
    id character(1) NOT NULL,
    nombre character varying(500) NOT NULL COLLATE public.es_co_utf_8,
    nomcorto character varying(10) NOT NULL,
    fechacreacion date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT tipo_violencia_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: sivel2_gen_victimacolectiva_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_victimacolectiva_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_victimacolectiva; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_victimacolectiva (
    personasaprox integer,
    organizacionarmada integer DEFAULT 35,
    id_grupoper integer NOT NULL,
    id_caso integer NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    id integer DEFAULT nextval('public.sivel2_gen_victimacolectiva_id_seq'::regclass) NOT NULL
);


--
-- Name: sivel2_gen_victimacolectiva_vinculoestado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_victimacolectiva_vinculoestado (
    id_vinculoestado integer DEFAULT 38 NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    victimacolectiva_id integer
);


--
-- Name: sivel2_gen_vinculoestado_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sivel2_gen_vinculoestado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sivel2_gen_vinculoestado; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sivel2_gen_vinculoestado (
    id integer DEFAULT nextval('public.sivel2_gen_vinculoestado_id_seq'::regclass) NOT NULL,
    nombre character varying(500) COLLATE public.es_co_utf_8,
    fechacreacion date DEFAULT '2001-01-01'::date NOT NULL,
    fechadeshabilitacion date,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    observaciones character varying(5000),
    CONSTRAINT vinculo_estado_check CHECK (((fechadeshabilitacion IS NULL) OR (fechadeshabilitacion >= fechacreacion)))
);


--
-- Name: spree_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_addresses (
    id integer NOT NULL,
    firstname character varying,
    lastname character varying,
    address1 character varying,
    address2 character varying,
    city character varying,
    zipcode character varying,
    phone character varying,
    state_name character varying,
    alternative_phone character varying,
    company character varying,
    state_id integer,
    country_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    name character varying
);


--
-- Name: spree_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_addresses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_addresses_id_seq OWNED BY public.spree_addresses.id;


--
-- Name: spree_adjustment_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_adjustment_reasons (
    id integer NOT NULL,
    name character varying,
    code character varying,
    active boolean DEFAULT true,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_adjustment_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_adjustment_reasons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_adjustment_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_adjustment_reasons_id_seq OWNED BY public.spree_adjustment_reasons.id;


--
-- Name: spree_adjustments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_adjustments (
    id integer NOT NULL,
    source_type character varying,
    source_id integer,
    adjustable_type character varying,
    adjustable_id integer NOT NULL,
    amount numeric(10,2),
    label character varying,
    eligible boolean DEFAULT true,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    order_id integer NOT NULL,
    included boolean DEFAULT false,
    promotion_code_id integer,
    adjustment_reason_id integer,
    finalized boolean DEFAULT false NOT NULL
);


--
-- Name: spree_adjustments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_adjustments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_adjustments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_adjustments_id_seq OWNED BY public.spree_adjustments.id;


--
-- Name: spree_assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_assets (
    id integer NOT NULL,
    viewable_type character varying,
    viewable_id integer,
    attachment_width integer,
    attachment_height integer,
    attachment_file_size integer,
    "position" integer,
    attachment_content_type character varying,
    attachment_file_name character varying,
    type character varying(75),
    attachment_updated_at timestamp without time zone,
    alt text,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_assets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_assets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_assets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_assets_id_seq OWNED BY public.spree_assets.id;


--
-- Name: spree_calculators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_calculators (
    id integer NOT NULL,
    type character varying,
    calculable_type character varying,
    calculable_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    preferences text
);


--
-- Name: spree_calculators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_calculators_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_calculators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_calculators_id_seq OWNED BY public.spree_calculators.id;


--
-- Name: spree_cartons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_cartons (
    id integer NOT NULL,
    number character varying,
    external_number character varying,
    stock_location_id integer,
    address_id integer,
    shipping_method_id integer,
    tracking character varying,
    shipped_at timestamp without time zone,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    imported_from_shipment_id integer
);


--
-- Name: spree_cartons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_cartons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_cartons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_cartons_id_seq OWNED BY public.spree_cartons.id;


--
-- Name: spree_countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_countries (
    id integer NOT NULL,
    iso_name character varying,
    iso character varying,
    iso3 character varying,
    name character varying,
    numcode integer,
    states_required boolean DEFAULT false,
    updated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone
);


--
-- Name: spree_countries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_countries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_countries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_countries_id_seq OWNED BY public.spree_countries.id;


--
-- Name: spree_credit_cards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_credit_cards (
    id integer NOT NULL,
    month character varying,
    year character varying,
    cc_type character varying,
    last_digits character varying,
    gateway_customer_profile_id character varying,
    gateway_payment_profile_id character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    name character varying,
    user_id integer,
    payment_method_id integer,
    "default" boolean DEFAULT false NOT NULL,
    address_id integer
);


--
-- Name: spree_credit_cards_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_credit_cards_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_credit_cards_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_credit_cards_id_seq OWNED BY public.spree_credit_cards.id;


--
-- Name: spree_customer_returns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_customer_returns (
    id integer NOT NULL,
    number character varying,
    stock_location_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_customer_returns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_customer_returns_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_customer_returns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_customer_returns_id_seq OWNED BY public.spree_customer_returns.id;


--
-- Name: spree_inventory_units; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_inventory_units (
    id integer NOT NULL,
    state character varying,
    variant_id integer,
    shipment_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    pending boolean DEFAULT true,
    line_item_id integer,
    carton_id integer
);


--
-- Name: spree_inventory_units_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_inventory_units_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_inventory_units_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_inventory_units_id_seq OWNED BY public.spree_inventory_units.id;


--
-- Name: spree_line_item_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_line_item_actions (
    id integer NOT NULL,
    line_item_id integer NOT NULL,
    action_id integer NOT NULL,
    quantity integer DEFAULT 0,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_line_item_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_line_item_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_line_item_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_line_item_actions_id_seq OWNED BY public.spree_line_item_actions.id;


--
-- Name: spree_line_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_line_items (
    id integer NOT NULL,
    variant_id integer,
    order_id integer,
    quantity integer NOT NULL,
    price numeric(10,2) NOT NULL,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    cost_price numeric(10,2),
    tax_category_id integer,
    adjustment_total numeric(10,2) DEFAULT 0.0,
    additional_tax_total numeric(10,2) DEFAULT 0.0,
    promo_total numeric(10,2) DEFAULT 0.0,
    included_tax_total numeric(10,2) DEFAULT 0.0 NOT NULL
);


--
-- Name: spree_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_line_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_line_items_id_seq OWNED BY public.spree_line_items.id;


--
-- Name: spree_log_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_log_entries (
    id integer NOT NULL,
    source_type character varying,
    source_id integer,
    details text,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_log_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_log_entries_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_log_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_log_entries_id_seq OWNED BY public.spree_log_entries.id;


--
-- Name: spree_option_type_prototypes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_option_type_prototypes (
    id integer NOT NULL,
    prototype_id integer,
    option_type_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_option_type_prototypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_option_type_prototypes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_option_type_prototypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_option_type_prototypes_id_seq OWNED BY public.spree_option_type_prototypes.id;


--
-- Name: spree_option_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_option_types (
    id integer NOT NULL,
    name character varying(100),
    presentation character varying(100),
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_option_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_option_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_option_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_option_types_id_seq OWNED BY public.spree_option_types.id;


--
-- Name: spree_option_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_option_values (
    id integer NOT NULL,
    "position" integer,
    name character varying,
    presentation character varying,
    option_type_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_option_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_option_values_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_option_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_option_values_id_seq OWNED BY public.spree_option_values.id;


--
-- Name: spree_option_values_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_option_values_variants (
    id integer NOT NULL,
    variant_id integer,
    option_value_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_option_values_variants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_option_values_variants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_option_values_variants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_option_values_variants_id_seq OWNED BY public.spree_option_values_variants.id;


--
-- Name: spree_order_mutexes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_order_mutexes (
    id integer NOT NULL,
    order_id integer NOT NULL,
    created_at timestamp(6) without time zone
);


--
-- Name: spree_order_mutexes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_order_mutexes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_order_mutexes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_order_mutexes_id_seq OWNED BY public.spree_order_mutexes.id;


--
-- Name: spree_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_orders (
    id integer NOT NULL,
    number character varying(32),
    item_total numeric(10,2) DEFAULT 0.0 NOT NULL,
    total numeric(10,2) DEFAULT 0.0 NOT NULL,
    state character varying,
    adjustment_total numeric(10,2) DEFAULT 0.0 NOT NULL,
    user_id integer,
    completed_at timestamp without time zone,
    bill_address_id integer,
    ship_address_id integer,
    payment_total numeric(10,2) DEFAULT 0.0,
    shipment_state character varying,
    payment_state character varying,
    email character varying,
    special_instructions text,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    currency character varying,
    last_ip_address character varying,
    created_by_id integer,
    shipment_total numeric(10,2) DEFAULT 0.0 NOT NULL,
    additional_tax_total numeric(10,2) DEFAULT 0.0,
    promo_total numeric(10,2) DEFAULT 0.0,
    channel character varying DEFAULT 'spree'::character varying,
    included_tax_total numeric(10,2) DEFAULT 0.0 NOT NULL,
    item_count integer DEFAULT 0,
    approver_id integer,
    approved_at timestamp without time zone,
    confirmation_delivered boolean DEFAULT false,
    guest_token character varying,
    canceled_at timestamp without time zone,
    canceler_id integer,
    store_id integer,
    approver_name character varying,
    frontend_viewable boolean DEFAULT true NOT NULL
);


--
-- Name: spree_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_orders_id_seq OWNED BY public.spree_orders.id;


--
-- Name: spree_orders_promotions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_orders_promotions (
    id integer NOT NULL,
    order_id integer,
    promotion_id integer,
    promotion_code_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_orders_promotions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_orders_promotions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_orders_promotions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_orders_promotions_id_seq OWNED BY public.spree_orders_promotions.id;


--
-- Name: spree_payment_capture_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_payment_capture_events (
    id integer NOT NULL,
    amount numeric(10,2) DEFAULT 0.0,
    payment_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_payment_capture_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_payment_capture_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_payment_capture_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_payment_capture_events_id_seq OWNED BY public.spree_payment_capture_events.id;


--
-- Name: spree_payment_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_payment_methods (
    id integer NOT NULL,
    type character varying,
    name character varying,
    description text,
    active boolean DEFAULT true,
    deleted_at timestamp without time zone,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    auto_capture boolean,
    preferences text,
    preference_source character varying,
    "position" integer DEFAULT 0,
    available_to_users boolean DEFAULT true,
    available_to_admin boolean DEFAULT true
);


--
-- Name: spree_payment_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_payment_methods_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_payment_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_payment_methods_id_seq OWNED BY public.spree_payment_methods.id;


--
-- Name: spree_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_payments (
    id integer NOT NULL,
    amount numeric(10,2) DEFAULT 0.0 NOT NULL,
    order_id integer,
    source_type character varying,
    source_id integer,
    payment_method_id integer,
    state character varying,
    response_code character varying,
    avs_response character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    number character varying,
    cvv_response_code character varying,
    cvv_response_message character varying
);


--
-- Name: spree_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_payments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_payments_id_seq OWNED BY public.spree_payments.id;


--
-- Name: spree_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_preferences (
    id integer NOT NULL,
    value text,
    key character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_preferences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_preferences_id_seq OWNED BY public.spree_preferences.id;


--
-- Name: spree_prices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_prices (
    id integer NOT NULL,
    variant_id integer NOT NULL,
    amount numeric(10,2) NOT NULL,
    currency character varying,
    deleted_at timestamp without time zone,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    country_iso character varying(2)
);


--
-- Name: spree_prices_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_prices_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_prices_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_prices_id_seq OWNED BY public.spree_prices.id;


--
-- Name: spree_product_option_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_product_option_types (
    id integer NOT NULL,
    "position" integer,
    product_id integer,
    option_type_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_product_option_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_product_option_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_product_option_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_product_option_types_id_seq OWNED BY public.spree_product_option_types.id;


--
-- Name: spree_product_promotion_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_product_promotion_rules (
    id integer NOT NULL,
    product_id integer,
    promotion_rule_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_product_promotion_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_product_promotion_rules_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_product_promotion_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_product_promotion_rules_id_seq OWNED BY public.spree_product_promotion_rules.id;


--
-- Name: spree_product_properties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_product_properties (
    id integer NOT NULL,
    value character varying,
    product_id integer,
    property_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    "position" integer DEFAULT 0
);


--
-- Name: spree_product_properties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_product_properties_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_product_properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_product_properties_id_seq OWNED BY public.spree_product_properties.id;


--
-- Name: spree_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_products (
    id integer NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    description text,
    available_on timestamp without time zone,
    deleted_at timestamp without time zone,
    slug character varying,
    meta_description text,
    meta_keywords character varying,
    tax_category_id integer,
    shipping_category_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    promotionable boolean DEFAULT true,
    meta_title character varying,
    discontinue_on timestamp without time zone
);


--
-- Name: spree_products_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_products_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_products_id_seq OWNED BY public.spree_products.id;


--
-- Name: spree_products_taxons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_products_taxons (
    id integer NOT NULL,
    product_id integer,
    taxon_id integer,
    "position" integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_products_taxons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_products_taxons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_products_taxons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_products_taxons_id_seq OWNED BY public.spree_products_taxons.id;


--
-- Name: spree_promotion_action_line_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_action_line_items (
    id integer NOT NULL,
    promotion_action_id integer,
    variant_id integer,
    quantity integer DEFAULT 1,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_promotion_action_line_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_action_line_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_action_line_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_action_line_items_id_seq OWNED BY public.spree_promotion_action_line_items.id;


--
-- Name: spree_promotion_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_actions (
    id integer NOT NULL,
    promotion_id integer,
    "position" integer,
    type character varying,
    deleted_at timestamp without time zone,
    preferences text,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_promotion_actions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_actions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_actions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_actions_id_seq OWNED BY public.spree_promotion_actions.id;


--
-- Name: spree_promotion_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_categories (
    id integer NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    code character varying
);


--
-- Name: spree_promotion_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_categories_id_seq OWNED BY public.spree_promotion_categories.id;


--
-- Name: spree_promotion_code_batches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_code_batches (
    id integer NOT NULL,
    promotion_id integer NOT NULL,
    base_code character varying NOT NULL,
    number_of_codes integer NOT NULL,
    email character varying,
    error character varying,
    state character varying DEFAULT 'pending'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    join_characters character varying DEFAULT '_'::character varying NOT NULL
);


--
-- Name: spree_promotion_code_batches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_code_batches_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_code_batches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_code_batches_id_seq OWNED BY public.spree_promotion_code_batches.id;


--
-- Name: spree_promotion_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_codes (
    id integer NOT NULL,
    promotion_id integer NOT NULL,
    value character varying NOT NULL,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    promotion_code_batch_id integer
);


--
-- Name: spree_promotion_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_codes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_codes_id_seq OWNED BY public.spree_promotion_codes.id;


--
-- Name: spree_promotion_rule_taxons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_rule_taxons (
    id integer NOT NULL,
    taxon_id integer,
    promotion_rule_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_promotion_rule_taxons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_rule_taxons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_rule_taxons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_rule_taxons_id_seq OWNED BY public.spree_promotion_rule_taxons.id;


--
-- Name: spree_promotion_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_rules (
    id integer NOT NULL,
    promotion_id integer,
    product_group_id integer,
    type character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    code character varying,
    preferences text
);


--
-- Name: spree_promotion_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_rules_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_rules_id_seq OWNED BY public.spree_promotion_rules.id;


--
-- Name: spree_promotion_rules_stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_rules_stores (
    id bigint NOT NULL,
    store_id bigint NOT NULL,
    promotion_rule_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_promotion_rules_stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_rules_stores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_rules_stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_rules_stores_id_seq OWNED BY public.spree_promotion_rules_stores.id;


--
-- Name: spree_promotion_rules_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotion_rules_users (
    id integer NOT NULL,
    user_id integer,
    promotion_rule_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_promotion_rules_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotion_rules_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotion_rules_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotion_rules_users_id_seq OWNED BY public.spree_promotion_rules_users.id;


--
-- Name: spree_promotions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_promotions (
    id integer NOT NULL,
    description character varying,
    expires_at timestamp without time zone,
    starts_at timestamp without time zone,
    name character varying,
    type character varying,
    usage_limit integer,
    match_policy character varying DEFAULT 'all'::character varying,
    advertise boolean DEFAULT false,
    path character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    promotion_category_id integer,
    per_code_usage_limit integer,
    apply_automatically boolean DEFAULT false
);


--
-- Name: spree_promotions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_promotions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_promotions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_promotions_id_seq OWNED BY public.spree_promotions.id;


--
-- Name: spree_properties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_properties (
    id integer NOT NULL,
    name character varying,
    presentation character varying NOT NULL,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_properties_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_properties_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_properties_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_properties_id_seq OWNED BY public.spree_properties.id;


--
-- Name: spree_property_prototypes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_property_prototypes (
    id integer NOT NULL,
    prototype_id integer,
    property_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_property_prototypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_property_prototypes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_property_prototypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_property_prototypes_id_seq OWNED BY public.spree_property_prototypes.id;


--
-- Name: spree_prototype_taxons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_prototype_taxons (
    id integer NOT NULL,
    taxon_id integer,
    prototype_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_prototype_taxons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_prototype_taxons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_prototype_taxons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_prototype_taxons_id_seq OWNED BY public.spree_prototype_taxons.id;


--
-- Name: spree_prototypes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_prototypes (
    id integer NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_prototypes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_prototypes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_prototypes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_prototypes_id_seq OWNED BY public.spree_prototypes.id;


--
-- Name: spree_refund_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_refund_reasons (
    id integer NOT NULL,
    name character varying,
    active boolean DEFAULT true,
    mutable boolean DEFAULT true,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    code character varying
);


--
-- Name: spree_refund_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_refund_reasons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_refund_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_refund_reasons_id_seq OWNED BY public.spree_refund_reasons.id;


--
-- Name: spree_refunds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_refunds (
    id integer NOT NULL,
    payment_id integer,
    amount numeric(10,2) DEFAULT 0.0 NOT NULL,
    transaction_id character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    refund_reason_id integer,
    reimbursement_id integer
);


--
-- Name: spree_refunds_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_refunds_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_refunds_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_refunds_id_seq OWNED BY public.spree_refunds.id;


--
-- Name: spree_reimbursement_credits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_reimbursement_credits (
    id integer NOT NULL,
    amount numeric(10,2) DEFAULT 0.0 NOT NULL,
    reimbursement_id integer,
    creditable_id integer,
    creditable_type character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_reimbursement_credits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_reimbursement_credits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_reimbursement_credits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_reimbursement_credits_id_seq OWNED BY public.spree_reimbursement_credits.id;


--
-- Name: spree_reimbursement_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_reimbursement_types (
    id integer NOT NULL,
    name character varying,
    active boolean DEFAULT true,
    mutable boolean DEFAULT true,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    type character varying
);


--
-- Name: spree_reimbursement_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_reimbursement_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_reimbursement_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_reimbursement_types_id_seq OWNED BY public.spree_reimbursement_types.id;


--
-- Name: spree_reimbursements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_reimbursements (
    id integer NOT NULL,
    number character varying,
    reimbursement_status character varying,
    customer_return_id integer,
    order_id integer,
    total numeric(10,2),
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_reimbursements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_reimbursements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_reimbursements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_reimbursements_id_seq OWNED BY public.spree_reimbursements.id;


--
-- Name: spree_return_authorizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_return_authorizations (
    id integer NOT NULL,
    number character varying,
    state character varying,
    order_id integer,
    memo text,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    stock_location_id integer,
    return_reason_id integer
);


--
-- Name: spree_return_authorizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_return_authorizations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_return_authorizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_return_authorizations_id_seq OWNED BY public.spree_return_authorizations.id;


--
-- Name: spree_return_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_return_items (
    id integer NOT NULL,
    return_authorization_id integer,
    inventory_unit_id integer,
    exchange_variant_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    amount numeric(12,4) DEFAULT 0.0 NOT NULL,
    included_tax_total numeric(12,4) DEFAULT 0.0 NOT NULL,
    additional_tax_total numeric(12,4) DEFAULT 0.0 NOT NULL,
    reception_status character varying,
    acceptance_status character varying,
    customer_return_id integer,
    reimbursement_id integer,
    exchange_inventory_unit_id integer,
    acceptance_status_errors text,
    preferred_reimbursement_type_id integer,
    override_reimbursement_type_id integer,
    resellable boolean DEFAULT true NOT NULL,
    return_reason_id integer
);


--
-- Name: spree_return_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_return_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_return_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_return_items_id_seq OWNED BY public.spree_return_items.id;


--
-- Name: spree_return_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_return_reasons (
    id integer NOT NULL,
    name character varying,
    active boolean DEFAULT true,
    mutable boolean DEFAULT true,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_return_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_return_reasons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_return_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_return_reasons_id_seq OWNED BY public.spree_return_reasons.id;


--
-- Name: spree_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_roles (
    id integer NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_roles_id_seq OWNED BY public.spree_roles.id;


--
-- Name: spree_roles_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_roles_users (
    id integer NOT NULL,
    role_id integer,
    user_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_roles_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_roles_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_roles_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_roles_users_id_seq OWNED BY public.spree_roles_users.id;


--
-- Name: spree_shipments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_shipments (
    id integer NOT NULL,
    tracking character varying,
    number character varying,
    cost numeric(10,2) DEFAULT 0.0,
    shipped_at timestamp without time zone,
    order_id integer,
    deprecated_address_id integer,
    state character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    stock_location_id integer,
    adjustment_total numeric(10,2) DEFAULT 0.0,
    additional_tax_total numeric(10,2) DEFAULT 0.0,
    promo_total numeric(10,2) DEFAULT 0.0,
    included_tax_total numeric(10,2) DEFAULT 0.0 NOT NULL
);


--
-- Name: spree_shipments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_shipments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_shipments_id_seq OWNED BY public.spree_shipments.id;


--
-- Name: spree_shipping_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_shipping_categories (
    id integer NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_shipping_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_shipping_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_shipping_categories_id_seq OWNED BY public.spree_shipping_categories.id;


--
-- Name: spree_shipping_method_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_shipping_method_categories (
    id integer NOT NULL,
    shipping_method_id integer NOT NULL,
    shipping_category_id integer NOT NULL,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_shipping_method_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_shipping_method_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_method_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_shipping_method_categories_id_seq OWNED BY public.spree_shipping_method_categories.id;


--
-- Name: spree_shipping_method_stock_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_shipping_method_stock_locations (
    id integer NOT NULL,
    shipping_method_id integer,
    stock_location_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_shipping_method_stock_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_shipping_method_stock_locations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_method_stock_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_shipping_method_stock_locations_id_seq OWNED BY public.spree_shipping_method_stock_locations.id;


--
-- Name: spree_shipping_method_zones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_shipping_method_zones (
    id integer NOT NULL,
    shipping_method_id integer,
    zone_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_shipping_method_zones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_shipping_method_zones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_method_zones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_shipping_method_zones_id_seq OWNED BY public.spree_shipping_method_zones.id;


--
-- Name: spree_shipping_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_shipping_methods (
    id integer NOT NULL,
    name character varying,
    deleted_at timestamp without time zone,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    tracking_url character varying,
    admin_name character varying,
    tax_category_id integer,
    code character varying,
    available_to_all boolean DEFAULT true,
    carrier character varying,
    service_level character varying,
    available_to_users boolean DEFAULT true
);


--
-- Name: spree_shipping_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_shipping_methods_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_shipping_methods_id_seq OWNED BY public.spree_shipping_methods.id;


--
-- Name: spree_shipping_rate_taxes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_shipping_rate_taxes (
    id integer NOT NULL,
    amount numeric(8,2) DEFAULT 0.0 NOT NULL,
    tax_rate_id integer,
    shipping_rate_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: spree_shipping_rate_taxes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_shipping_rate_taxes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_rate_taxes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_shipping_rate_taxes_id_seq OWNED BY public.spree_shipping_rate_taxes.id;


--
-- Name: spree_shipping_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_shipping_rates (
    id integer NOT NULL,
    shipment_id integer,
    shipping_method_id integer,
    selected boolean DEFAULT false,
    cost numeric(8,2) DEFAULT 0.0,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    tax_rate_id integer
);


--
-- Name: spree_shipping_rates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_shipping_rates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_shipping_rates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_shipping_rates_id_seq OWNED BY public.spree_shipping_rates.id;


--
-- Name: spree_state_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_state_changes (
    id integer NOT NULL,
    name character varying,
    previous_state character varying,
    stateful_id integer,
    user_id integer,
    stateful_type character varying,
    next_state character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_state_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_state_changes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_state_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_state_changes_id_seq OWNED BY public.spree_state_changes.id;


--
-- Name: spree_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_states (
    id integer NOT NULL,
    name character varying,
    abbr character varying,
    country_id integer,
    updated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone
);


--
-- Name: spree_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_states_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_states_id_seq OWNED BY public.spree_states.id;


--
-- Name: spree_stock_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_stock_items (
    id integer NOT NULL,
    stock_location_id integer,
    variant_id integer,
    count_on_hand integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    backorderable boolean DEFAULT false,
    deleted_at timestamp without time zone
);


--
-- Name: spree_stock_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_stock_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stock_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_stock_items_id_seq OWNED BY public.spree_stock_items.id;


--
-- Name: spree_stock_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_stock_locations (
    id integer NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    "default" boolean DEFAULT false NOT NULL,
    address1 character varying,
    address2 character varying,
    city character varying,
    state_id integer,
    state_name character varying,
    country_id integer,
    zipcode character varying,
    phone character varying,
    active boolean DEFAULT true,
    backorderable_default boolean DEFAULT false,
    propagate_all_variants boolean DEFAULT true,
    admin_name character varying,
    "position" integer DEFAULT 0,
    restock_inventory boolean DEFAULT true NOT NULL,
    fulfillable boolean DEFAULT true NOT NULL,
    code character varying,
    check_stock_on_transfer boolean DEFAULT true
);


--
-- Name: spree_stock_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_stock_locations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stock_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_stock_locations_id_seq OWNED BY public.spree_stock_locations.id;


--
-- Name: spree_stock_movements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_stock_movements (
    id integer NOT NULL,
    stock_item_id integer,
    quantity integer DEFAULT 0,
    action character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    originator_type character varying,
    originator_id integer
);


--
-- Name: spree_stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_stock_movements_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_stock_movements_id_seq OWNED BY public.spree_stock_movements.id;


--
-- Name: spree_store_credit_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_store_credit_categories (
    id integer NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_store_credit_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_store_credit_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_store_credit_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_store_credit_categories_id_seq OWNED BY public.spree_store_credit_categories.id;


--
-- Name: spree_store_credit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_store_credit_events (
    id integer NOT NULL,
    store_credit_id integer NOT NULL,
    action character varying NOT NULL,
    amount numeric(8,2),
    user_total_amount numeric(8,2) DEFAULT 0.0 NOT NULL,
    authorization_code character varying NOT NULL,
    deleted_at timestamp without time zone,
    originator_type character varying,
    originator_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    amount_remaining numeric(8,2) DEFAULT NULL::numeric,
    store_credit_reason_id integer
);


--
-- Name: spree_store_credit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_store_credit_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_store_credit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_store_credit_events_id_seq OWNED BY public.spree_store_credit_events.id;


--
-- Name: spree_store_credit_reasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_store_credit_reasons (
    id bigint NOT NULL,
    name character varying,
    active boolean DEFAULT true,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: spree_store_credit_reasons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_store_credit_reasons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_store_credit_reasons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_store_credit_reasons_id_seq OWNED BY public.spree_store_credit_reasons.id;


--
-- Name: spree_store_credit_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_store_credit_types (
    id integer NOT NULL,
    name character varying,
    priority integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_store_credit_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_store_credit_types_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_store_credit_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_store_credit_types_id_seq OWNED BY public.spree_store_credit_types.id;


--
-- Name: spree_store_credits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_store_credits (
    id integer NOT NULL,
    user_id integer,
    category_id integer,
    created_by_id integer,
    amount numeric(8,2) DEFAULT 0.0 NOT NULL,
    amount_used numeric(8,2) DEFAULT 0.0 NOT NULL,
    amount_authorized numeric(8,2) DEFAULT 0.0 NOT NULL,
    currency character varying,
    memo text,
    deleted_at timestamp without time zone,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    type_id integer,
    invalidated_at timestamp without time zone
);


--
-- Name: spree_store_credits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_store_credits_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_store_credits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_store_credits_id_seq OWNED BY public.spree_store_credits.id;


--
-- Name: spree_store_payment_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_store_payment_methods (
    id integer NOT NULL,
    store_id integer NOT NULL,
    payment_method_id integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: spree_store_payment_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_store_payment_methods_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_store_payment_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_store_payment_methods_id_seq OWNED BY public.spree_store_payment_methods.id;


--
-- Name: spree_store_shipping_methods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_store_shipping_methods (
    id bigint NOT NULL,
    store_id bigint NOT NULL,
    shipping_method_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: spree_store_shipping_methods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_store_shipping_methods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_store_shipping_methods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_store_shipping_methods_id_seq OWNED BY public.spree_store_shipping_methods.id;


--
-- Name: spree_stores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_stores (
    id integer NOT NULL,
    name character varying,
    url character varying,
    meta_description text,
    meta_keywords text,
    seo_title character varying,
    mail_from_address character varying,
    default_currency character varying,
    code character varying,
    "default" boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    cart_tax_country_iso character varying,
    available_locales character varying,
    bcc_email character varying
);


--
-- Name: spree_stores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_stores_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_stores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_stores_id_seq OWNED BY public.spree_stores.id;


--
-- Name: spree_tax_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_tax_categories (
    id integer NOT NULL,
    name character varying,
    description character varying,
    is_default boolean DEFAULT false,
    deleted_at timestamp without time zone,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    tax_code character varying
);


--
-- Name: spree_tax_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_tax_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_tax_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_tax_categories_id_seq OWNED BY public.spree_tax_categories.id;


--
-- Name: spree_tax_rate_tax_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_tax_rate_tax_categories (
    id integer NOT NULL,
    tax_category_id integer NOT NULL,
    tax_rate_id integer NOT NULL
);


--
-- Name: spree_tax_rate_tax_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_tax_rate_tax_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_tax_rate_tax_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_tax_rate_tax_categories_id_seq OWNED BY public.spree_tax_rate_tax_categories.id;


--
-- Name: spree_tax_rates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_tax_rates (
    id integer NOT NULL,
    amount numeric(8,5),
    zone_id integer,
    included_in_price boolean DEFAULT false,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    name character varying,
    show_rate_in_label boolean DEFAULT true,
    deleted_at timestamp without time zone,
    starts_at timestamp without time zone,
    expires_at timestamp without time zone
);


--
-- Name: spree_tax_rates_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_tax_rates_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_tax_rates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_tax_rates_id_seq OWNED BY public.spree_tax_rates.id;


--
-- Name: spree_taxonomies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_taxonomies (
    id integer NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    "position" integer DEFAULT 0
);


--
-- Name: spree_taxonomies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_taxonomies_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_taxonomies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_taxonomies_id_seq OWNED BY public.spree_taxonomies.id;


--
-- Name: spree_taxons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_taxons (
    id integer NOT NULL,
    parent_id integer,
    "position" integer DEFAULT 0,
    name character varying NOT NULL,
    permalink character varying,
    taxonomy_id integer,
    lft integer,
    rgt integer,
    icon_file_name character varying,
    icon_content_type character varying,
    icon_file_size integer,
    icon_updated_at timestamp without time zone,
    description text,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone,
    meta_title character varying,
    meta_description character varying,
    meta_keywords character varying,
    depth integer
);


--
-- Name: spree_taxons_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_taxons_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_taxons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_taxons_id_seq OWNED BY public.spree_taxons.id;


--
-- Name: spree_unit_cancels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_unit_cancels (
    id integer NOT NULL,
    inventory_unit_id integer NOT NULL,
    reason character varying,
    created_by character varying,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_unit_cancels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_unit_cancels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_unit_cancels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_unit_cancels_id_seq OWNED BY public.spree_unit_cancels.id;


--
-- Name: spree_user_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_user_addresses (
    id integer NOT NULL,
    user_id integer NOT NULL,
    address_id integer NOT NULL,
    "default" boolean DEFAULT false,
    archived boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    default_billing boolean DEFAULT false
);


--
-- Name: spree_user_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_user_addresses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_user_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_user_addresses_id_seq OWNED BY public.spree_user_addresses.id;


--
-- Name: spree_user_stock_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_user_stock_locations (
    id integer NOT NULL,
    user_id integer,
    stock_location_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_user_stock_locations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_user_stock_locations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_user_stock_locations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_user_stock_locations_id_seq OWNED BY public.spree_user_stock_locations.id;


--
-- Name: spree_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_users (
    id integer NOT NULL,
    crypted_password character varying(128),
    salt character varying(128),
    email character varying,
    remember_token character varying,
    remember_token_expires_at character varying,
    persistence_token character varying,
    single_access_token character varying,
    perishable_token character varying,
    login_count integer DEFAULT 0 NOT NULL,
    failed_login_count integer DEFAULT 0 NOT NULL,
    last_request_at timestamp without time zone,
    current_login_at timestamp without time zone,
    last_login_at timestamp without time zone,
    current_login_ip character varying,
    last_login_ip character varying,
    login character varying,
    ship_address_id integer,
    bill_address_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    openid_identifier character varying,
    spree_api_key character varying(48)
);


--
-- Name: spree_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_users_id_seq OWNED BY public.spree_users.id;


--
-- Name: spree_variant_property_rule_conditions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_variant_property_rule_conditions (
    id integer NOT NULL,
    option_value_id integer,
    variant_property_rule_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: spree_variant_property_rule_conditions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_variant_property_rule_conditions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_variant_property_rule_conditions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_variant_property_rule_conditions_id_seq OWNED BY public.spree_variant_property_rule_conditions.id;


--
-- Name: spree_variant_property_rule_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_variant_property_rule_values (
    id integer NOT NULL,
    value text,
    "position" integer DEFAULT 0,
    property_id integer,
    variant_property_rule_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_variant_property_rule_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_variant_property_rule_values_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_variant_property_rule_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_variant_property_rule_values_id_seq OWNED BY public.spree_variant_property_rule_values.id;


--
-- Name: spree_variant_property_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_variant_property_rules (
    id integer NOT NULL,
    product_id integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    apply_to_all boolean DEFAULT true NOT NULL
);


--
-- Name: spree_variant_property_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_variant_property_rules_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_variant_property_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_variant_property_rules_id_seq OWNED BY public.spree_variant_property_rules.id;


--
-- Name: spree_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_variants (
    id integer NOT NULL,
    sku character varying DEFAULT ''::character varying NOT NULL,
    weight numeric(8,2) DEFAULT 0.0,
    height numeric(8,2),
    width numeric(8,2),
    depth numeric(8,2),
    deleted_at timestamp without time zone,
    is_master boolean DEFAULT false,
    product_id integer,
    cost_price numeric(10,2),
    "position" integer,
    cost_currency character varying,
    track_inventory boolean DEFAULT true,
    tax_category_id integer,
    updated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone
);


--
-- Name: spree_variants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_variants_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_variants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_variants_id_seq OWNED BY public.spree_variants.id;


--
-- Name: spree_wallet_payment_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_wallet_payment_sources (
    id integer NOT NULL,
    user_id integer NOT NULL,
    payment_source_type character varying NOT NULL,
    payment_source_id integer NOT NULL,
    "default" boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: spree_wallet_payment_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_wallet_payment_sources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_wallet_payment_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_wallet_payment_sources_id_seq OWNED BY public.spree_wallet_payment_sources.id;


--
-- Name: spree_zone_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_zone_members (
    id integer NOT NULL,
    zoneable_type character varying,
    zoneable_id integer,
    zone_id integer,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_zone_members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_zone_members_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_zone_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_zone_members_id_seq OWNED BY public.spree_zone_members.id;


--
-- Name: spree_zones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.spree_zones (
    id integer NOT NULL,
    name character varying,
    description character varying,
    zone_members_count integer DEFAULT 0,
    created_at timestamp(6) without time zone,
    updated_at timestamp(6) without time zone
);


--
-- Name: spree_zones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.spree_zones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: spree_zones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.spree_zones_id_seq OWNED BY public.spree_zones.id;


--
-- Name: vvictimasoundexesp; Type: MATERIALIZED VIEW; Schema: public; Owner: -
--

CREATE MATERIALIZED VIEW public.vvictimasoundexesp AS
 SELECT sivel2_gen_victima.id_caso,
    sip_persona.id AS id_persona,
    (((sip_persona.nombres)::text || ' '::text) || (sip_persona.apellidos)::text) AS nomap,
    public.soundexespm((((sip_persona.nombres)::text || ' '::text) || (sip_persona.apellidos)::text)) AS nomsoundexesp
   FROM public.sip_persona,
    public.sivel2_gen_victima
  WHERE (sip_persona.id = sivel2_gen_victima.id_persona)
  WITH NO DATA;


--
-- Name: action_mailbox_inbound_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_mailbox_inbound_emails ALTER COLUMN id SET DEFAULT nextval('public.action_mailbox_inbound_emails_id_seq'::regclass);


--
-- Name: action_text_rich_texts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts ALTER COLUMN id SET DEFAULT nextval('public.action_text_rich_texts_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: friendly_id_slugs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs ALTER COLUMN id SET DEFAULT nextval('public.friendly_id_slugs_id_seq'::regclass);


--
-- Name: heb412_gen_campohc id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_campohc ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_campohc_id_seq'::regclass);


--
-- Name: heb412_gen_campoplantillahcm id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_campoplantillahcm ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_campoplantillahcm_id_seq'::regclass);


--
-- Name: heb412_gen_campoplantillahcr id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_campoplantillahcr ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_campoplantillahcr_id_seq'::regclass);


--
-- Name: heb412_gen_carpetaexclusiva id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_carpetaexclusiva ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_carpetaexclusiva_id_seq'::regclass);


--
-- Name: heb412_gen_doc id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_doc ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_doc_id_seq'::regclass);


--
-- Name: heb412_gen_formulario_plantillahcr id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_formulario_plantillahcr ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_formulario_plantillahcr_id_seq'::regclass);


--
-- Name: heb412_gen_plantilladoc id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_plantilladoc ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_plantilladoc_id_seq'::regclass);


--
-- Name: heb412_gen_plantillahcm id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_plantillahcm ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_plantillahcm_id_seq'::regclass);


--
-- Name: heb412_gen_plantillahcr id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_plantillahcr ALTER COLUMN id SET DEFAULT nextval('public.heb412_gen_plantillahcr_id_seq'::regclass);


--
-- Name: mr519_gen_campo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_campo ALTER COLUMN id SET DEFAULT nextval('public.mr519_gen_campo_id_seq'::regclass);


--
-- Name: mr519_gen_encuestapersona id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestapersona ALTER COLUMN id SET DEFAULT nextval('public.mr519_gen_encuestapersona_id_seq'::regclass);


--
-- Name: mr519_gen_encuestausuario id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestausuario ALTER COLUMN id SET DEFAULT nextval('public.mr519_gen_encuestausuario_id_seq'::regclass);


--
-- Name: mr519_gen_formulario id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_formulario ALTER COLUMN id SET DEFAULT nextval('public.mr519_gen_formulario_id_seq'::regclass);


--
-- Name: mr519_gen_opcioncs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_opcioncs ALTER COLUMN id SET DEFAULT nextval('public.mr519_gen_opcioncs_id_seq'::regclass);


--
-- Name: mr519_gen_planencuesta id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_planencuesta ALTER COLUMN id SET DEFAULT nextval('public.mr519_gen_planencuesta_id_seq'::regclass);


--
-- Name: mr519_gen_respuestafor id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_respuestafor ALTER COLUMN id SET DEFAULT nextval('public.mr519_gen_respuestafor_id_seq'::regclass);


--
-- Name: mr519_gen_valorcampo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_valorcampo ALTER COLUMN id SET DEFAULT nextval('public.mr519_gen_valorcampo_id_seq'::regclass);


--
-- Name: paypal_commerce_platform_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paypal_commerce_platform_sources ALTER COLUMN id SET DEFAULT nextval('public.paypal_commerce_platform_sources_id_seq'::regclass);


--
-- Name: sip_anexo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_anexo ALTER COLUMN id SET DEFAULT nextval('public.sip_anexo_id_seq'::regclass);


--
-- Name: sip_bitacora id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_bitacora ALTER COLUMN id SET DEFAULT nextval('public.sip_bitacora_id_seq'::regclass);


--
-- Name: sip_grupo id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_grupo ALTER COLUMN id SET DEFAULT nextval('public.sip_grupo_id_seq'::regclass);


--
-- Name: sip_oficina id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_oficina ALTER COLUMN id SET DEFAULT nextval('public.sip_oficina_id_seq'::regclass);


--
-- Name: sip_orgsocial id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial ALTER COLUMN id SET DEFAULT nextval('public.sip_orgsocial_id_seq'::regclass);


--
-- Name: sip_orgsocial_persona id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial_persona ALTER COLUMN id SET DEFAULT nextval('public.sip_orgsocial_persona_id_seq'::regclass);


--
-- Name: sip_pais id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_pais ALTER COLUMN id SET DEFAULT nextval('public.sip_pais_id_seq'::regclass);


--
-- Name: sip_perfilorgsocial id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_perfilorgsocial ALTER COLUMN id SET DEFAULT nextval('public.sip_perfilorgsocial_id_seq'::regclass);


--
-- Name: sip_sectororgsocial id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_sectororgsocial ALTER COLUMN id SET DEFAULT nextval('public.sip_sectororgsocial_id_seq'::regclass);


--
-- Name: sip_tdocumento id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_tdocumento ALTER COLUMN id SET DEFAULT nextval('public.sip_tdocumento_id_seq'::regclass);


--
-- Name: sip_tema id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_tema ALTER COLUMN id SET DEFAULT nextval('public.sip_tema_id_seq'::regclass);


--
-- Name: sip_trivalente id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_trivalente ALTER COLUMN id SET DEFAULT nextval('public.sip_trivalente_id_seq'::regclass);


--
-- Name: sip_ubicacionpre id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacionpre ALTER COLUMN id SET DEFAULT nextval('public.sip_ubicacionpre_id_seq'::regclass);


--
-- Name: sivel2_gen_actividadoficio id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actividadoficio ALTER COLUMN id SET DEFAULT nextval('public.sivel2_gen_actividadoficio_id_seq'::regclass);


--
-- Name: sivel2_gen_combatiente id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente ALTER COLUMN id SET DEFAULT nextval('public.sivel2_gen_combatiente_id_seq'::regclass);


--
-- Name: sivel2_gen_contextovictima id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_contextovictima ALTER COLUMN id SET DEFAULT nextval('public.sivel2_gen_contextovictima_id_seq'::regclass);


--
-- Name: sivel2_gen_escolaridad id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_escolaridad ALTER COLUMN id SET DEFAULT nextval('public.sivel2_gen_escolaridad_id_seq'::regclass);


--
-- Name: sivel2_gen_estadocivil id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_estadocivil ALTER COLUMN id SET DEFAULT nextval('public.sivel2_gen_estadocivil_id_seq'::regclass);


--
-- Name: sivel2_gen_maternidad id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_maternidad ALTER COLUMN id SET DEFAULT nextval('public.sivel2_gen_maternidad_id_seq'::regclass);


--
-- Name: sivel2_gen_resagresion id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_resagresion ALTER COLUMN id SET DEFAULT nextval('public.sivel2_gen_resagresion_id_seq'::regclass);


--
-- Name: spree_addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_addresses ALTER COLUMN id SET DEFAULT nextval('public.spree_addresses_id_seq'::regclass);


--
-- Name: spree_adjustment_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_adjustment_reasons ALTER COLUMN id SET DEFAULT nextval('public.spree_adjustment_reasons_id_seq'::regclass);


--
-- Name: spree_adjustments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_adjustments ALTER COLUMN id SET DEFAULT nextval('public.spree_adjustments_id_seq'::regclass);


--
-- Name: spree_assets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_assets ALTER COLUMN id SET DEFAULT nextval('public.spree_assets_id_seq'::regclass);


--
-- Name: spree_calculators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_calculators ALTER COLUMN id SET DEFAULT nextval('public.spree_calculators_id_seq'::regclass);


--
-- Name: spree_cartons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_cartons ALTER COLUMN id SET DEFAULT nextval('public.spree_cartons_id_seq'::regclass);


--
-- Name: spree_countries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_countries ALTER COLUMN id SET DEFAULT nextval('public.spree_countries_id_seq'::regclass);


--
-- Name: spree_credit_cards id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_credit_cards ALTER COLUMN id SET DEFAULT nextval('public.spree_credit_cards_id_seq'::regclass);


--
-- Name: spree_customer_returns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_customer_returns ALTER COLUMN id SET DEFAULT nextval('public.spree_customer_returns_id_seq'::regclass);


--
-- Name: spree_inventory_units id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_inventory_units ALTER COLUMN id SET DEFAULT nextval('public.spree_inventory_units_id_seq'::regclass);


--
-- Name: spree_line_item_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_line_item_actions ALTER COLUMN id SET DEFAULT nextval('public.spree_line_item_actions_id_seq'::regclass);


--
-- Name: spree_line_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_line_items ALTER COLUMN id SET DEFAULT nextval('public.spree_line_items_id_seq'::regclass);


--
-- Name: spree_log_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_log_entries ALTER COLUMN id SET DEFAULT nextval('public.spree_log_entries_id_seq'::regclass);


--
-- Name: spree_option_type_prototypes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_option_type_prototypes ALTER COLUMN id SET DEFAULT nextval('public.spree_option_type_prototypes_id_seq'::regclass);


--
-- Name: spree_option_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_option_types ALTER COLUMN id SET DEFAULT nextval('public.spree_option_types_id_seq'::regclass);


--
-- Name: spree_option_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_option_values ALTER COLUMN id SET DEFAULT nextval('public.spree_option_values_id_seq'::regclass);


--
-- Name: spree_option_values_variants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_option_values_variants ALTER COLUMN id SET DEFAULT nextval('public.spree_option_values_variants_id_seq'::regclass);


--
-- Name: spree_order_mutexes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_order_mutexes ALTER COLUMN id SET DEFAULT nextval('public.spree_order_mutexes_id_seq'::regclass);


--
-- Name: spree_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_orders ALTER COLUMN id SET DEFAULT nextval('public.spree_orders_id_seq'::regclass);


--
-- Name: spree_orders_promotions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_orders_promotions ALTER COLUMN id SET DEFAULT nextval('public.spree_orders_promotions_id_seq'::regclass);


--
-- Name: spree_payment_capture_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_payment_capture_events ALTER COLUMN id SET DEFAULT nextval('public.spree_payment_capture_events_id_seq'::regclass);


--
-- Name: spree_payment_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_payment_methods ALTER COLUMN id SET DEFAULT nextval('public.spree_payment_methods_id_seq'::regclass);


--
-- Name: spree_payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_payments ALTER COLUMN id SET DEFAULT nextval('public.spree_payments_id_seq'::regclass);


--
-- Name: spree_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_preferences ALTER COLUMN id SET DEFAULT nextval('public.spree_preferences_id_seq'::regclass);


--
-- Name: spree_prices id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_prices ALTER COLUMN id SET DEFAULT nextval('public.spree_prices_id_seq'::regclass);


--
-- Name: spree_product_option_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_product_option_types ALTER COLUMN id SET DEFAULT nextval('public.spree_product_option_types_id_seq'::regclass);


--
-- Name: spree_product_promotion_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_product_promotion_rules ALTER COLUMN id SET DEFAULT nextval('public.spree_product_promotion_rules_id_seq'::regclass);


--
-- Name: spree_product_properties id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_product_properties ALTER COLUMN id SET DEFAULT nextval('public.spree_product_properties_id_seq'::regclass);


--
-- Name: spree_products id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_products ALTER COLUMN id SET DEFAULT nextval('public.spree_products_id_seq'::regclass);


--
-- Name: spree_products_taxons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_products_taxons ALTER COLUMN id SET DEFAULT nextval('public.spree_products_taxons_id_seq'::regclass);


--
-- Name: spree_promotion_action_line_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_action_line_items ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_action_line_items_id_seq'::regclass);


--
-- Name: spree_promotion_actions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_actions ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_actions_id_seq'::regclass);


--
-- Name: spree_promotion_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_categories ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_categories_id_seq'::regclass);


--
-- Name: spree_promotion_code_batches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_code_batches ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_code_batches_id_seq'::regclass);


--
-- Name: spree_promotion_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_codes ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_codes_id_seq'::regclass);


--
-- Name: spree_promotion_rule_taxons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_rule_taxons ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_rule_taxons_id_seq'::regclass);


--
-- Name: spree_promotion_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_rules ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_rules_id_seq'::regclass);


--
-- Name: spree_promotion_rules_stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_rules_stores ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_rules_stores_id_seq'::regclass);


--
-- Name: spree_promotion_rules_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_rules_users ALTER COLUMN id SET DEFAULT nextval('public.spree_promotion_rules_users_id_seq'::regclass);


--
-- Name: spree_promotions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotions ALTER COLUMN id SET DEFAULT nextval('public.spree_promotions_id_seq'::regclass);


--
-- Name: spree_properties id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_properties ALTER COLUMN id SET DEFAULT nextval('public.spree_properties_id_seq'::regclass);


--
-- Name: spree_property_prototypes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_property_prototypes ALTER COLUMN id SET DEFAULT nextval('public.spree_property_prototypes_id_seq'::regclass);


--
-- Name: spree_prototype_taxons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_prototype_taxons ALTER COLUMN id SET DEFAULT nextval('public.spree_prototype_taxons_id_seq'::regclass);


--
-- Name: spree_prototypes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_prototypes ALTER COLUMN id SET DEFAULT nextval('public.spree_prototypes_id_seq'::regclass);


--
-- Name: spree_refund_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_refund_reasons ALTER COLUMN id SET DEFAULT nextval('public.spree_refund_reasons_id_seq'::regclass);


--
-- Name: spree_refunds id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_refunds ALTER COLUMN id SET DEFAULT nextval('public.spree_refunds_id_seq'::regclass);


--
-- Name: spree_reimbursement_credits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_reimbursement_credits ALTER COLUMN id SET DEFAULT nextval('public.spree_reimbursement_credits_id_seq'::regclass);


--
-- Name: spree_reimbursement_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_reimbursement_types ALTER COLUMN id SET DEFAULT nextval('public.spree_reimbursement_types_id_seq'::regclass);


--
-- Name: spree_reimbursements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_reimbursements ALTER COLUMN id SET DEFAULT nextval('public.spree_reimbursements_id_seq'::regclass);


--
-- Name: spree_return_authorizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_return_authorizations ALTER COLUMN id SET DEFAULT nextval('public.spree_return_authorizations_id_seq'::regclass);


--
-- Name: spree_return_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_return_items ALTER COLUMN id SET DEFAULT nextval('public.spree_return_items_id_seq'::regclass);


--
-- Name: spree_return_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_return_reasons ALTER COLUMN id SET DEFAULT nextval('public.spree_return_reasons_id_seq'::regclass);


--
-- Name: spree_roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_roles ALTER COLUMN id SET DEFAULT nextval('public.spree_roles_id_seq'::regclass);


--
-- Name: spree_roles_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_roles_users ALTER COLUMN id SET DEFAULT nextval('public.spree_roles_users_id_seq'::regclass);


--
-- Name: spree_shipments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipments ALTER COLUMN id SET DEFAULT nextval('public.spree_shipments_id_seq'::regclass);


--
-- Name: spree_shipping_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_categories ALTER COLUMN id SET DEFAULT nextval('public.spree_shipping_categories_id_seq'::regclass);


--
-- Name: spree_shipping_method_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_method_categories ALTER COLUMN id SET DEFAULT nextval('public.spree_shipping_method_categories_id_seq'::regclass);


--
-- Name: spree_shipping_method_stock_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_method_stock_locations ALTER COLUMN id SET DEFAULT nextval('public.spree_shipping_method_stock_locations_id_seq'::regclass);


--
-- Name: spree_shipping_method_zones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_method_zones ALTER COLUMN id SET DEFAULT nextval('public.spree_shipping_method_zones_id_seq'::regclass);


--
-- Name: spree_shipping_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_methods ALTER COLUMN id SET DEFAULT nextval('public.spree_shipping_methods_id_seq'::regclass);


--
-- Name: spree_shipping_rate_taxes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_rate_taxes ALTER COLUMN id SET DEFAULT nextval('public.spree_shipping_rate_taxes_id_seq'::regclass);


--
-- Name: spree_shipping_rates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_rates ALTER COLUMN id SET DEFAULT nextval('public.spree_shipping_rates_id_seq'::regclass);


--
-- Name: spree_state_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_state_changes ALTER COLUMN id SET DEFAULT nextval('public.spree_state_changes_id_seq'::regclass);


--
-- Name: spree_states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_states ALTER COLUMN id SET DEFAULT nextval('public.spree_states_id_seq'::regclass);


--
-- Name: spree_stock_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_stock_items ALTER COLUMN id SET DEFAULT nextval('public.spree_stock_items_id_seq'::regclass);


--
-- Name: spree_stock_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_stock_locations ALTER COLUMN id SET DEFAULT nextval('public.spree_stock_locations_id_seq'::regclass);


--
-- Name: spree_stock_movements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_stock_movements ALTER COLUMN id SET DEFAULT nextval('public.spree_stock_movements_id_seq'::regclass);


--
-- Name: spree_store_credit_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credit_categories ALTER COLUMN id SET DEFAULT nextval('public.spree_store_credit_categories_id_seq'::regclass);


--
-- Name: spree_store_credit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credit_events ALTER COLUMN id SET DEFAULT nextval('public.spree_store_credit_events_id_seq'::regclass);


--
-- Name: spree_store_credit_reasons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credit_reasons ALTER COLUMN id SET DEFAULT nextval('public.spree_store_credit_reasons_id_seq'::regclass);


--
-- Name: spree_store_credit_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credit_types ALTER COLUMN id SET DEFAULT nextval('public.spree_store_credit_types_id_seq'::regclass);


--
-- Name: spree_store_credits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credits ALTER COLUMN id SET DEFAULT nextval('public.spree_store_credits_id_seq'::regclass);


--
-- Name: spree_store_payment_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_payment_methods ALTER COLUMN id SET DEFAULT nextval('public.spree_store_payment_methods_id_seq'::regclass);


--
-- Name: spree_store_shipping_methods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_shipping_methods ALTER COLUMN id SET DEFAULT nextval('public.spree_store_shipping_methods_id_seq'::regclass);


--
-- Name: spree_stores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_stores ALTER COLUMN id SET DEFAULT nextval('public.spree_stores_id_seq'::regclass);


--
-- Name: spree_tax_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_tax_categories ALTER COLUMN id SET DEFAULT nextval('public.spree_tax_categories_id_seq'::regclass);


--
-- Name: spree_tax_rate_tax_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_tax_rate_tax_categories ALTER COLUMN id SET DEFAULT nextval('public.spree_tax_rate_tax_categories_id_seq'::regclass);


--
-- Name: spree_tax_rates id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_tax_rates ALTER COLUMN id SET DEFAULT nextval('public.spree_tax_rates_id_seq'::regclass);


--
-- Name: spree_taxonomies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_taxonomies ALTER COLUMN id SET DEFAULT nextval('public.spree_taxonomies_id_seq'::regclass);


--
-- Name: spree_taxons id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_taxons ALTER COLUMN id SET DEFAULT nextval('public.spree_taxons_id_seq'::regclass);


--
-- Name: spree_unit_cancels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_unit_cancels ALTER COLUMN id SET DEFAULT nextval('public.spree_unit_cancels_id_seq'::regclass);


--
-- Name: spree_user_addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_user_addresses ALTER COLUMN id SET DEFAULT nextval('public.spree_user_addresses_id_seq'::regclass);


--
-- Name: spree_user_stock_locations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_user_stock_locations ALTER COLUMN id SET DEFAULT nextval('public.spree_user_stock_locations_id_seq'::regclass);


--
-- Name: spree_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_users ALTER COLUMN id SET DEFAULT nextval('public.spree_users_id_seq'::regclass);


--
-- Name: spree_variant_property_rule_conditions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_variant_property_rule_conditions ALTER COLUMN id SET DEFAULT nextval('public.spree_variant_property_rule_conditions_id_seq'::regclass);


--
-- Name: spree_variant_property_rule_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_variant_property_rule_values ALTER COLUMN id SET DEFAULT nextval('public.spree_variant_property_rule_values_id_seq'::regclass);


--
-- Name: spree_variant_property_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_variant_property_rules ALTER COLUMN id SET DEFAULT nextval('public.spree_variant_property_rules_id_seq'::regclass);


--
-- Name: spree_variants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_variants ALTER COLUMN id SET DEFAULT nextval('public.spree_variants_id_seq'::regclass);


--
-- Name: spree_wallet_payment_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_wallet_payment_sources ALTER COLUMN id SET DEFAULT nextval('public.spree_wallet_payment_sources_id_seq'::regclass);


--
-- Name: spree_zone_members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_zone_members ALTER COLUMN id SET DEFAULT nextval('public.spree_zone_members_id_seq'::regclass);


--
-- Name: spree_zones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_zones ALTER COLUMN id SET DEFAULT nextval('public.spree_zones_id_seq'::regclass);


--
-- Name: action_mailbox_inbound_emails action_mailbox_inbound_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_mailbox_inbound_emails
    ADD CONSTRAINT action_mailbox_inbound_emails_pkey PRIMARY KEY (id);


--
-- Name: action_text_rich_texts action_text_rich_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts
    ADD CONSTRAINT action_text_rich_texts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_acto acto_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_acto
    ADD CONSTRAINT acto_id_key UNIQUE (id);


--
-- Name: sivel2_gen_acto acto_id_presponsable_id_categoria_id_persona_id_caso_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_acto
    ADD CONSTRAINT acto_id_presponsable_id_categoria_id_persona_id_caso_key UNIQUE (id_presponsable, id_categoria, id_persona, id_caso);


--
-- Name: antecedente_combatiente antecedente_combatiente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.antecedente_combatiente
    ADD CONSTRAINT antecedente_combatiente_pkey PRIMARY KEY (id_antecedente, id_combatiente);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: sivel2_gen_caso_etiqueta caso_etiqueta_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_etiqueta
    ADD CONSTRAINT caso_etiqueta_id_key UNIQUE (id);


--
-- Name: sivel2_gen_caso_presponsable caso_presponsable_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_presponsable
    ADD CONSTRAINT caso_presponsable_id_key UNIQUE (id);


--
-- Name: sivel2_gen_categoria categoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_categoria
    ADD CONSTRAINT categoria_pkey PRIMARY KEY (id);


--
-- Name: combatiente combatiente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.combatiente
    ADD CONSTRAINT combatiente_pkey PRIMARY KEY (id);


--
-- Name: friendly_id_slugs friendly_id_slugs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendly_id_slugs
    ADD CONSTRAINT friendly_id_slugs_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_caso_frontera frontera_caso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_frontera
    ADD CONSTRAINT frontera_caso_pkey PRIMARY KEY (id_frontera, id_caso);


--
-- Name: sivel2_gen_caso_usuario funcionario_caso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_usuario
    ADD CONSTRAINT funcionario_caso_pkey PRIMARY KEY (id_usuario, id_caso);


--
-- Name: heb412_gen_campohc heb412_gen_campohc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_campohc
    ADD CONSTRAINT heb412_gen_campohc_pkey PRIMARY KEY (id);


--
-- Name: heb412_gen_campoplantillahcm heb412_gen_campoplantillahcm_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_campoplantillahcm
    ADD CONSTRAINT heb412_gen_campoplantillahcm_pkey PRIMARY KEY (id);


--
-- Name: heb412_gen_campoplantillahcr heb412_gen_campoplantillahcr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_campoplantillahcr
    ADD CONSTRAINT heb412_gen_campoplantillahcr_pkey PRIMARY KEY (id);


--
-- Name: heb412_gen_carpetaexclusiva heb412_gen_carpetaexclusiva_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_carpetaexclusiva
    ADD CONSTRAINT heb412_gen_carpetaexclusiva_pkey PRIMARY KEY (id);


--
-- Name: heb412_gen_doc heb412_gen_doc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_doc
    ADD CONSTRAINT heb412_gen_doc_pkey PRIMARY KEY (id);


--
-- Name: heb412_gen_formulario_plantillahcr heb412_gen_formulario_plantillahcr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_formulario_plantillahcr
    ADD CONSTRAINT heb412_gen_formulario_plantillahcr_pkey PRIMARY KEY (id);


--
-- Name: heb412_gen_plantilladoc heb412_gen_plantilladoc_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_plantilladoc
    ADD CONSTRAINT heb412_gen_plantilladoc_pkey PRIMARY KEY (id);


--
-- Name: heb412_gen_plantillahcm heb412_gen_plantillahcm_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_plantillahcm
    ADD CONSTRAINT heb412_gen_plantillahcm_pkey PRIMARY KEY (id);


--
-- Name: heb412_gen_plantillahcr heb412_gen_plantillahcr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_plantillahcr
    ADD CONSTRAINT heb412_gen_plantillahcr_pkey PRIMARY KEY (id);


--
-- Name: mr519_gen_campo mr519_gen_campo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_campo
    ADD CONSTRAINT mr519_gen_campo_pkey PRIMARY KEY (id);


--
-- Name: mr519_gen_encuestapersona mr519_gen_encuestapersona_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestapersona
    ADD CONSTRAINT mr519_gen_encuestapersona_pkey PRIMARY KEY (id);


--
-- Name: mr519_gen_encuestausuario mr519_gen_encuestausuario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestausuario
    ADD CONSTRAINT mr519_gen_encuestausuario_pkey PRIMARY KEY (id);


--
-- Name: mr519_gen_formulario mr519_gen_formulario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_formulario
    ADD CONSTRAINT mr519_gen_formulario_pkey PRIMARY KEY (id);


--
-- Name: mr519_gen_opcioncs mr519_gen_opcioncs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_opcioncs
    ADD CONSTRAINT mr519_gen_opcioncs_pkey PRIMARY KEY (id);


--
-- Name: mr519_gen_planencuesta mr519_gen_planencuesta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_planencuesta
    ADD CONSTRAINT mr519_gen_planencuesta_pkey PRIMARY KEY (id);


--
-- Name: mr519_gen_respuestafor mr519_gen_respuestafor_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_respuestafor
    ADD CONSTRAINT mr519_gen_respuestafor_pkey PRIMARY KEY (id);


--
-- Name: mr519_gen_valorcampo mr519_gen_valorcampo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_valorcampo
    ADD CONSTRAINT mr519_gen_valorcampo_pkey PRIMARY KEY (id);


--
-- Name: combatiente_presponsable p_responsable_agrede_combatiente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.combatiente_presponsable
    ADD CONSTRAINT p_responsable_agrede_combatiente_pkey PRIMARY KEY (id_p_responsable, id_combatiente);


--
-- Name: paypal_commerce_platform_sources paypal_commerce_platform_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paypal_commerce_platform_sources
    ADD CONSTRAINT paypal_commerce_platform_sources_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_pconsolidado pconsolidado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_pconsolidado
    ADD CONSTRAINT pconsolidado_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_caso_region region_caso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_region
    ADD CONSTRAINT region_caso_pkey PRIMARY KEY (id_region, id_caso);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sip_anexo sip_anexo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_anexo
    ADD CONSTRAINT sip_anexo_pkey PRIMARY KEY (id);


--
-- Name: sip_bitacora sip_bitacora_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_bitacora
    ADD CONSTRAINT sip_bitacora_pkey PRIMARY KEY (id);


--
-- Name: sip_clase sip_clase_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_clase
    ADD CONSTRAINT sip_clase_id_key UNIQUE (id);


--
-- Name: sip_clase sip_clase_id_municipio_id_clalocal_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_clase
    ADD CONSTRAINT sip_clase_id_municipio_id_clalocal_key UNIQUE (id_municipio, id_clalocal);


--
-- Name: sip_clase sip_clase_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_clase
    ADD CONSTRAINT sip_clase_pkey PRIMARY KEY (id);


--
-- Name: sip_departamento sip_departamento_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_departamento
    ADD CONSTRAINT sip_departamento_id_key UNIQUE (id);


--
-- Name: sip_departamento sip_departamento_id_pais_id_deplocal_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_departamento
    ADD CONSTRAINT sip_departamento_id_pais_id_deplocal_key UNIQUE (id_pais, id_deplocal);


--
-- Name: sip_departamento sip_departamento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_departamento
    ADD CONSTRAINT sip_departamento_pkey PRIMARY KEY (id);


--
-- Name: sip_grupo sip_grupo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_grupo
    ADD CONSTRAINT sip_grupo_pkey PRIMARY KEY (id);


--
-- Name: sip_grupoper sip_grupoper_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_grupoper
    ADD CONSTRAINT sip_grupoper_pkey PRIMARY KEY (id);


--
-- Name: sip_municipio sip_municipio_id_departamento_id_munlocal_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_municipio
    ADD CONSTRAINT sip_municipio_id_departamento_id_munlocal_key UNIQUE (id_departamento, id_munlocal);


--
-- Name: sip_municipio sip_municipio_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_municipio
    ADD CONSTRAINT sip_municipio_id_key UNIQUE (id);


--
-- Name: sip_municipio sip_municipio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_municipio
    ADD CONSTRAINT sip_municipio_pkey PRIMARY KEY (id);


--
-- Name: sip_orgsocial_persona sip_orgsocial_persona_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial_persona
    ADD CONSTRAINT sip_orgsocial_persona_pkey PRIMARY KEY (id);


--
-- Name: sip_orgsocial sip_orgsocial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial
    ADD CONSTRAINT sip_orgsocial_pkey PRIMARY KEY (id);


--
-- Name: sip_perfilorgsocial sip_perfilorgsocial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_perfilorgsocial
    ADD CONSTRAINT sip_perfilorgsocial_pkey PRIMARY KEY (id);


--
-- Name: sip_persona_trelacion sip_persona_trelacion_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona_trelacion
    ADD CONSTRAINT sip_persona_trelacion_id_key UNIQUE (id);


--
-- Name: sip_persona_trelacion sip_persona_trelacion_persona1_persona2_id_trelacion_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona_trelacion
    ADD CONSTRAINT sip_persona_trelacion_persona1_persona2_id_trelacion_key UNIQUE (persona1, persona2, id_trelacion);


--
-- Name: sip_persona_trelacion sip_persona_trelacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona_trelacion
    ADD CONSTRAINT sip_persona_trelacion_pkey PRIMARY KEY (id);


--
-- Name: sip_sectororgsocial sip_sectororgsocial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_sectororgsocial
    ADD CONSTRAINT sip_sectororgsocial_pkey PRIMARY KEY (id);


--
-- Name: sip_tema sip_tema_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_tema
    ADD CONSTRAINT sip_tema_pkey PRIMARY KEY (id);


--
-- Name: sip_trivalente sip_trivalente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_trivalente
    ADD CONSTRAINT sip_trivalente_pkey PRIMARY KEY (id);


--
-- Name: sip_ubicacionpre sip_ubicacionpre_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacionpre
    ADD CONSTRAINT sip_ubicacionpre_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_actividadoficio sivel2_gen_actividadoficio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actividadoficio
    ADD CONSTRAINT sivel2_gen_actividadoficio_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_acto sivel2_gen_acto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_acto
    ADD CONSTRAINT sivel2_gen_acto_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_actocolectivo sivel2_gen_actocolectivo_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actocolectivo
    ADD CONSTRAINT sivel2_gen_actocolectivo_id_key UNIQUE (id);


--
-- Name: sivel2_gen_actocolectivo sivel2_gen_actocolectivo_id_presponsable_id_categoria_id_gr_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actocolectivo
    ADD CONSTRAINT sivel2_gen_actocolectivo_id_presponsable_id_categoria_id_gr_key UNIQUE (id_presponsable, id_categoria, id_grupoper, id_caso);


--
-- Name: sivel2_gen_actocolectivo sivel2_gen_actocolectivo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actocolectivo
    ADD CONSTRAINT sivel2_gen_actocolectivo_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_anexo_caso sivel2_gen_anexo_caso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_anexo_caso
    ADD CONSTRAINT sivel2_gen_anexo_caso_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_antecedente sivel2_gen_antecedente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente
    ADD CONSTRAINT sivel2_gen_antecedente_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_caso_categoria_presponsable sivel2_gen_caso_categoria_pre_id_caso_presponsable_id_categ_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_categoria_presponsable
    ADD CONSTRAINT sivel2_gen_caso_categoria_pre_id_caso_presponsable_id_categ_key UNIQUE (id_caso_presponsable, id_categoria);


--
-- Name: sivel2_gen_caso_categoria_presponsable sivel2_gen_caso_categoria_presponsable_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_categoria_presponsable
    ADD CONSTRAINT sivel2_gen_caso_categoria_presponsable_id_key UNIQUE (id);


--
-- Name: sivel2_gen_caso_categoria_presponsable sivel2_gen_caso_categoria_presponsable_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_categoria_presponsable
    ADD CONSTRAINT sivel2_gen_caso_categoria_presponsable_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_caso_etiqueta sivel2_gen_caso_etiqueta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_etiqueta
    ADD CONSTRAINT sivel2_gen_caso_etiqueta_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_caso_fotra sivel2_gen_caso_fotra_id_caso_nombre_fecha_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fotra
    ADD CONSTRAINT sivel2_gen_caso_fotra_id_caso_nombre_fecha_key UNIQUE (id_caso, nombre, fecha);


--
-- Name: sivel2_gen_caso_fotra sivel2_gen_caso_fotra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fotra
    ADD CONSTRAINT sivel2_gen_caso_fotra_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_caso_fuenteprensa sivel2_gen_caso_fuenteprensa_id_caso_fecha_fuenteprensa_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fuenteprensa
    ADD CONSTRAINT sivel2_gen_caso_fuenteprensa_id_caso_fecha_fuenteprensa_id_key UNIQUE (id_caso, fecha, fuenteprensa_id);


--
-- Name: sivel2_gen_caso_fuenteprensa sivel2_gen_caso_fuenteprensa_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fuenteprensa
    ADD CONSTRAINT sivel2_gen_caso_fuenteprensa_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_caso sivel2_gen_caso_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso
    ADD CONSTRAINT sivel2_gen_caso_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_caso_presponsable sivel2_gen_caso_presponsable_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_presponsable
    ADD CONSTRAINT sivel2_gen_caso_presponsable_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_combatiente sivel2_gen_combatiente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT sivel2_gen_combatiente_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_contexto sivel2_gen_contexto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_contexto
    ADD CONSTRAINT sivel2_gen_contexto_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_contextovictima sivel2_gen_contextovictima_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_contextovictima
    ADD CONSTRAINT sivel2_gen_contextovictima_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_escolaridad sivel2_gen_escolaridad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_escolaridad
    ADD CONSTRAINT sivel2_gen_escolaridad_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_estadocivil sivel2_gen_estadocivil_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_estadocivil
    ADD CONSTRAINT sivel2_gen_estadocivil_pkey PRIMARY KEY (id);


--
-- Name: sip_etiqueta sivel2_gen_etiqueta_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_etiqueta
    ADD CONSTRAINT sivel2_gen_etiqueta_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_etnia sivel2_gen_etnia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_etnia
    ADD CONSTRAINT sivel2_gen_etnia_pkey PRIMARY KEY (id);


--
-- Name: sip_fuenteprensa sivel2_gen_ffrecuente_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_fuenteprensa
    ADD CONSTRAINT sivel2_gen_ffrecuente_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_filiacion sivel2_gen_filiacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_filiacion
    ADD CONSTRAINT sivel2_gen_filiacion_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_fotra sivel2_gen_fotra_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_fotra
    ADD CONSTRAINT sivel2_gen_fotra_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_frontera sivel2_gen_frontera_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_frontera
    ADD CONSTRAINT sivel2_gen_frontera_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_iglesia sivel2_gen_iglesia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_iglesia
    ADD CONSTRAINT sivel2_gen_iglesia_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_intervalo sivel2_gen_intervalo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_intervalo
    ADD CONSTRAINT sivel2_gen_intervalo_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_maternidad sivel2_gen_maternidad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_maternidad
    ADD CONSTRAINT sivel2_gen_maternidad_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_organizacion sivel2_gen_organizacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_organizacion
    ADD CONSTRAINT sivel2_gen_organizacion_pkey PRIMARY KEY (id);


--
-- Name: sip_pais sivel2_gen_pais_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_pais
    ADD CONSTRAINT sivel2_gen_pais_pkey PRIMARY KEY (id);


--
-- Name: sip_persona sivel2_gen_persona_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona
    ADD CONSTRAINT sivel2_gen_persona_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_presponsable sivel2_gen_presponsable_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_presponsable
    ADD CONSTRAINT sivel2_gen_presponsable_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_profesion sivel2_gen_profesion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_profesion
    ADD CONSTRAINT sivel2_gen_profesion_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_rangoedad sivel2_gen_rangoedad_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_rangoedad
    ADD CONSTRAINT sivel2_gen_rangoedad_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_region sivel2_gen_region_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_region
    ADD CONSTRAINT sivel2_gen_region_pkey PRIMARY KEY (id);


--
-- Name: sip_oficina sivel2_gen_regionsjr_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_oficina
    ADD CONSTRAINT sivel2_gen_regionsjr_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_resagresion sivel2_gen_resagresion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_resagresion
    ADD CONSTRAINT sivel2_gen_resagresion_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_sectorsocial sivel2_gen_sectorsocial_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_sectorsocial
    ADD CONSTRAINT sivel2_gen_sectorsocial_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_supracategoria sivel2_gen_supracategoria_id_tviolencia_codigo_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_supracategoria
    ADD CONSTRAINT sivel2_gen_supracategoria_id_tviolencia_codigo_key UNIQUE (id_tviolencia, codigo);


--
-- Name: sivel2_gen_supracategoria sivel2_gen_supracategoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_supracategoria
    ADD CONSTRAINT sivel2_gen_supracategoria_pkey PRIMARY KEY (id);


--
-- Name: sip_tdocumento sivel2_gen_tdocumento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_tdocumento
    ADD CONSTRAINT sivel2_gen_tdocumento_pkey PRIMARY KEY (id);


--
-- Name: sip_tsitio sivel2_gen_tsitio_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_tsitio
    ADD CONSTRAINT sivel2_gen_tsitio_pkey PRIMARY KEY (id);


--
-- Name: sip_ubicacion sivel2_gen_ubicacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT sivel2_gen_ubicacion_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_victima sivel2_gen_victima_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT sivel2_gen_victima_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_victimacolectiva sivel2_gen_victimacolectiva_id_caso_id_grupoper_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva
    ADD CONSTRAINT sivel2_gen_victimacolectiva_id_caso_id_grupoper_key UNIQUE (id_caso, id_grupoper);


--
-- Name: sivel2_gen_victimacolectiva sivel2_gen_victimacolectiva_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva
    ADD CONSTRAINT sivel2_gen_victimacolectiva_id_key UNIQUE (id);


--
-- Name: sivel2_gen_victimacolectiva sivel2_gen_victimacolectiva_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva
    ADD CONSTRAINT sivel2_gen_victimacolectiva_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_vinculoestado sivel2_gen_vinculoestado_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_vinculoestado
    ADD CONSTRAINT sivel2_gen_vinculoestado_pkey PRIMARY KEY (id);


--
-- Name: spree_addresses spree_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_addresses
    ADD CONSTRAINT spree_addresses_pkey PRIMARY KEY (id);


--
-- Name: spree_adjustment_reasons spree_adjustment_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_adjustment_reasons
    ADD CONSTRAINT spree_adjustment_reasons_pkey PRIMARY KEY (id);


--
-- Name: spree_adjustments spree_adjustments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_adjustments
    ADD CONSTRAINT spree_adjustments_pkey PRIMARY KEY (id);


--
-- Name: spree_assets spree_assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_assets
    ADD CONSTRAINT spree_assets_pkey PRIMARY KEY (id);


--
-- Name: spree_calculators spree_calculators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_calculators
    ADD CONSTRAINT spree_calculators_pkey PRIMARY KEY (id);


--
-- Name: spree_cartons spree_cartons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_cartons
    ADD CONSTRAINT spree_cartons_pkey PRIMARY KEY (id);


--
-- Name: spree_countries spree_countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_countries
    ADD CONSTRAINT spree_countries_pkey PRIMARY KEY (id);


--
-- Name: spree_credit_cards spree_credit_cards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_credit_cards
    ADD CONSTRAINT spree_credit_cards_pkey PRIMARY KEY (id);


--
-- Name: spree_customer_returns spree_customer_returns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_customer_returns
    ADD CONSTRAINT spree_customer_returns_pkey PRIMARY KEY (id);


--
-- Name: spree_inventory_units spree_inventory_units_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_inventory_units
    ADD CONSTRAINT spree_inventory_units_pkey PRIMARY KEY (id);


--
-- Name: spree_line_item_actions spree_line_item_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_line_item_actions
    ADD CONSTRAINT spree_line_item_actions_pkey PRIMARY KEY (id);


--
-- Name: spree_line_items spree_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_line_items
    ADD CONSTRAINT spree_line_items_pkey PRIMARY KEY (id);


--
-- Name: spree_log_entries spree_log_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_log_entries
    ADD CONSTRAINT spree_log_entries_pkey PRIMARY KEY (id);


--
-- Name: spree_option_type_prototypes spree_option_type_prototypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_option_type_prototypes
    ADD CONSTRAINT spree_option_type_prototypes_pkey PRIMARY KEY (id);


--
-- Name: spree_option_types spree_option_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_option_types
    ADD CONSTRAINT spree_option_types_pkey PRIMARY KEY (id);


--
-- Name: spree_option_values spree_option_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_option_values
    ADD CONSTRAINT spree_option_values_pkey PRIMARY KEY (id);


--
-- Name: spree_option_values_variants spree_option_values_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_option_values_variants
    ADD CONSTRAINT spree_option_values_variants_pkey PRIMARY KEY (id);


--
-- Name: spree_order_mutexes spree_order_mutexes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_order_mutexes
    ADD CONSTRAINT spree_order_mutexes_pkey PRIMARY KEY (id);


--
-- Name: spree_orders spree_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_orders
    ADD CONSTRAINT spree_orders_pkey PRIMARY KEY (id);


--
-- Name: spree_orders_promotions spree_orders_promotions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_orders_promotions
    ADD CONSTRAINT spree_orders_promotions_pkey PRIMARY KEY (id);


--
-- Name: spree_payment_capture_events spree_payment_capture_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_payment_capture_events
    ADD CONSTRAINT spree_payment_capture_events_pkey PRIMARY KEY (id);


--
-- Name: spree_payment_methods spree_payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_payment_methods
    ADD CONSTRAINT spree_payment_methods_pkey PRIMARY KEY (id);


--
-- Name: spree_payments spree_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_payments
    ADD CONSTRAINT spree_payments_pkey PRIMARY KEY (id);


--
-- Name: spree_preferences spree_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_preferences
    ADD CONSTRAINT spree_preferences_pkey PRIMARY KEY (id);


--
-- Name: spree_prices spree_prices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_prices
    ADD CONSTRAINT spree_prices_pkey PRIMARY KEY (id);


--
-- Name: spree_product_option_types spree_product_option_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_product_option_types
    ADD CONSTRAINT spree_product_option_types_pkey PRIMARY KEY (id);


--
-- Name: spree_product_promotion_rules spree_product_promotion_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_product_promotion_rules
    ADD CONSTRAINT spree_product_promotion_rules_pkey PRIMARY KEY (id);


--
-- Name: spree_product_properties spree_product_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_product_properties
    ADD CONSTRAINT spree_product_properties_pkey PRIMARY KEY (id);


--
-- Name: spree_products spree_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_products
    ADD CONSTRAINT spree_products_pkey PRIMARY KEY (id);


--
-- Name: spree_products_taxons spree_products_taxons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_products_taxons
    ADD CONSTRAINT spree_products_taxons_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_action_line_items spree_promotion_action_line_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_action_line_items
    ADD CONSTRAINT spree_promotion_action_line_items_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_actions spree_promotion_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_actions
    ADD CONSTRAINT spree_promotion_actions_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_categories spree_promotion_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_categories
    ADD CONSTRAINT spree_promotion_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_code_batches spree_promotion_code_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_code_batches
    ADD CONSTRAINT spree_promotion_code_batches_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_codes spree_promotion_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_codes
    ADD CONSTRAINT spree_promotion_codes_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_rule_taxons spree_promotion_rule_taxons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_rule_taxons
    ADD CONSTRAINT spree_promotion_rule_taxons_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_rules spree_promotion_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_rules
    ADD CONSTRAINT spree_promotion_rules_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_rules_stores spree_promotion_rules_stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_rules_stores
    ADD CONSTRAINT spree_promotion_rules_stores_pkey PRIMARY KEY (id);


--
-- Name: spree_promotion_rules_users spree_promotion_rules_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_rules_users
    ADD CONSTRAINT spree_promotion_rules_users_pkey PRIMARY KEY (id);


--
-- Name: spree_promotions spree_promotions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotions
    ADD CONSTRAINT spree_promotions_pkey PRIMARY KEY (id);


--
-- Name: spree_properties spree_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_properties
    ADD CONSTRAINT spree_properties_pkey PRIMARY KEY (id);


--
-- Name: spree_property_prototypes spree_property_prototypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_property_prototypes
    ADD CONSTRAINT spree_property_prototypes_pkey PRIMARY KEY (id);


--
-- Name: spree_prototype_taxons spree_prototype_taxons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_prototype_taxons
    ADD CONSTRAINT spree_prototype_taxons_pkey PRIMARY KEY (id);


--
-- Name: spree_prototypes spree_prototypes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_prototypes
    ADD CONSTRAINT spree_prototypes_pkey PRIMARY KEY (id);


--
-- Name: spree_refund_reasons spree_refund_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_refund_reasons
    ADD CONSTRAINT spree_refund_reasons_pkey PRIMARY KEY (id);


--
-- Name: spree_refunds spree_refunds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_refunds
    ADD CONSTRAINT spree_refunds_pkey PRIMARY KEY (id);


--
-- Name: spree_reimbursement_credits spree_reimbursement_credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_reimbursement_credits
    ADD CONSTRAINT spree_reimbursement_credits_pkey PRIMARY KEY (id);


--
-- Name: spree_reimbursement_types spree_reimbursement_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_reimbursement_types
    ADD CONSTRAINT spree_reimbursement_types_pkey PRIMARY KEY (id);


--
-- Name: spree_reimbursements spree_reimbursements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_reimbursements
    ADD CONSTRAINT spree_reimbursements_pkey PRIMARY KEY (id);


--
-- Name: spree_return_authorizations spree_return_authorizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_return_authorizations
    ADD CONSTRAINT spree_return_authorizations_pkey PRIMARY KEY (id);


--
-- Name: spree_return_items spree_return_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_return_items
    ADD CONSTRAINT spree_return_items_pkey PRIMARY KEY (id);


--
-- Name: spree_return_reasons spree_return_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_return_reasons
    ADD CONSTRAINT spree_return_reasons_pkey PRIMARY KEY (id);


--
-- Name: spree_roles spree_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_roles
    ADD CONSTRAINT spree_roles_pkey PRIMARY KEY (id);


--
-- Name: spree_roles_users spree_roles_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_roles_users
    ADD CONSTRAINT spree_roles_users_pkey PRIMARY KEY (id);


--
-- Name: spree_shipments spree_shipments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipments
    ADD CONSTRAINT spree_shipments_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_categories spree_shipping_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_categories
    ADD CONSTRAINT spree_shipping_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_method_categories spree_shipping_method_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_method_categories
    ADD CONSTRAINT spree_shipping_method_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_method_stock_locations spree_shipping_method_stock_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_method_stock_locations
    ADD CONSTRAINT spree_shipping_method_stock_locations_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_method_zones spree_shipping_method_zones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_method_zones
    ADD CONSTRAINT spree_shipping_method_zones_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_methods spree_shipping_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_methods
    ADD CONSTRAINT spree_shipping_methods_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_rate_taxes spree_shipping_rate_taxes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_rate_taxes
    ADD CONSTRAINT spree_shipping_rate_taxes_pkey PRIMARY KEY (id);


--
-- Name: spree_shipping_rates spree_shipping_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_shipping_rates
    ADD CONSTRAINT spree_shipping_rates_pkey PRIMARY KEY (id);


--
-- Name: spree_state_changes spree_state_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_state_changes
    ADD CONSTRAINT spree_state_changes_pkey PRIMARY KEY (id);


--
-- Name: spree_states spree_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_states
    ADD CONSTRAINT spree_states_pkey PRIMARY KEY (id);


--
-- Name: spree_stock_items spree_stock_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_stock_items
    ADD CONSTRAINT spree_stock_items_pkey PRIMARY KEY (id);


--
-- Name: spree_stock_locations spree_stock_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_stock_locations
    ADD CONSTRAINT spree_stock_locations_pkey PRIMARY KEY (id);


--
-- Name: spree_stock_movements spree_stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_stock_movements
    ADD CONSTRAINT spree_stock_movements_pkey PRIMARY KEY (id);


--
-- Name: spree_store_credit_categories spree_store_credit_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credit_categories
    ADD CONSTRAINT spree_store_credit_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_store_credit_events spree_store_credit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credit_events
    ADD CONSTRAINT spree_store_credit_events_pkey PRIMARY KEY (id);


--
-- Name: spree_store_credit_reasons spree_store_credit_reasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credit_reasons
    ADD CONSTRAINT spree_store_credit_reasons_pkey PRIMARY KEY (id);


--
-- Name: spree_store_credit_types spree_store_credit_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credit_types
    ADD CONSTRAINT spree_store_credit_types_pkey PRIMARY KEY (id);


--
-- Name: spree_store_credits spree_store_credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_credits
    ADD CONSTRAINT spree_store_credits_pkey PRIMARY KEY (id);


--
-- Name: spree_store_payment_methods spree_store_payment_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_payment_methods
    ADD CONSTRAINT spree_store_payment_methods_pkey PRIMARY KEY (id);


--
-- Name: spree_store_shipping_methods spree_store_shipping_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_store_shipping_methods
    ADD CONSTRAINT spree_store_shipping_methods_pkey PRIMARY KEY (id);


--
-- Name: spree_stores spree_stores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_stores
    ADD CONSTRAINT spree_stores_pkey PRIMARY KEY (id);


--
-- Name: spree_tax_categories spree_tax_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_tax_categories
    ADD CONSTRAINT spree_tax_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_tax_rate_tax_categories spree_tax_rate_tax_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_tax_rate_tax_categories
    ADD CONSTRAINT spree_tax_rate_tax_categories_pkey PRIMARY KEY (id);


--
-- Name: spree_tax_rates spree_tax_rates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_tax_rates
    ADD CONSTRAINT spree_tax_rates_pkey PRIMARY KEY (id);


--
-- Name: spree_taxonomies spree_taxonomies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_taxonomies
    ADD CONSTRAINT spree_taxonomies_pkey PRIMARY KEY (id);


--
-- Name: spree_taxons spree_taxons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_taxons
    ADD CONSTRAINT spree_taxons_pkey PRIMARY KEY (id);


--
-- Name: spree_unit_cancels spree_unit_cancels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_unit_cancels
    ADD CONSTRAINT spree_unit_cancels_pkey PRIMARY KEY (id);


--
-- Name: spree_user_addresses spree_user_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_user_addresses
    ADD CONSTRAINT spree_user_addresses_pkey PRIMARY KEY (id);


--
-- Name: spree_user_stock_locations spree_user_stock_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_user_stock_locations
    ADD CONSTRAINT spree_user_stock_locations_pkey PRIMARY KEY (id);


--
-- Name: spree_users spree_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_users
    ADD CONSTRAINT spree_users_pkey PRIMARY KEY (id);


--
-- Name: spree_variant_property_rule_conditions spree_variant_property_rule_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_variant_property_rule_conditions
    ADD CONSTRAINT spree_variant_property_rule_conditions_pkey PRIMARY KEY (id);


--
-- Name: spree_variant_property_rule_values spree_variant_property_rule_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_variant_property_rule_values
    ADD CONSTRAINT spree_variant_property_rule_values_pkey PRIMARY KEY (id);


--
-- Name: spree_variant_property_rules spree_variant_property_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_variant_property_rules
    ADD CONSTRAINT spree_variant_property_rules_pkey PRIMARY KEY (id);


--
-- Name: spree_variants spree_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_variants
    ADD CONSTRAINT spree_variants_pkey PRIMARY KEY (id);


--
-- Name: spree_wallet_payment_sources spree_wallet_payment_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_wallet_payment_sources
    ADD CONSTRAINT spree_wallet_payment_sources_pkey PRIMARY KEY (id);


--
-- Name: spree_zone_members spree_zone_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_zone_members
    ADD CONSTRAINT spree_zone_members_pkey PRIMARY KEY (id);


--
-- Name: spree_zones spree_zones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_zones
    ADD CONSTRAINT spree_zones_pkey PRIMARY KEY (id);


--
-- Name: sip_tclase tipo_clase_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_tclase
    ADD CONSTRAINT tipo_clase_pkey PRIMARY KEY (id);


--
-- Name: sip_trelacion tipo_relacion_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_trelacion
    ADD CONSTRAINT tipo_relacion_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_tviolencia tipo_violencia_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_tviolencia
    ADD CONSTRAINT tipo_violencia_pkey PRIMARY KEY (id);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);


--
-- Name: sivel2_gen_victima victima_id_caso_id_persona_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_caso_id_persona_key UNIQUE (id_caso, id_persona);


--
-- Name: sivel2_gen_victima victima_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_key UNIQUE (id);


--
-- Name: busca_sivel2_gen_conscaso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX busca_sivel2_gen_conscaso ON public.sivel2_gen_conscaso USING gin (q);


--
-- Name: caso_fecha_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX caso_fecha_idx ON public.sivel2_gen_caso USING btree (fecha);


--
-- Name: caso_fecha_idx1; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX caso_fecha_idx1 ON public.sivel2_gen_caso USING btree (fecha);


--
-- Name: index_action_mailbox_inbound_emails_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_mailbox_inbound_emails_uniqueness ON public.action_mailbox_inbound_emails USING btree (message_id, message_checksum);


--
-- Name: index_action_text_rich_texts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_text_rich_texts_uniqueness ON public.action_text_rich_texts USING btree (record_type, record_id, name);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_addresses_on_firstname; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_firstname ON public.spree_addresses USING btree (firstname);


--
-- Name: index_addresses_on_lastname; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_lastname ON public.spree_addresses USING btree (lastname);


--
-- Name: index_adjustments_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_adjustments_on_order_id ON public.spree_adjustments USING btree (adjustable_id);


--
-- Name: index_assets_on_viewable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assets_on_viewable_id ON public.spree_assets USING btree (viewable_id);


--
-- Name: index_assets_on_viewable_type_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_assets_on_viewable_type_and_type ON public.spree_assets USING btree (viewable_type, type);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type ON public.friendly_id_slugs USING btree (slug, sluggable_type);


--
-- Name: index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope ON public.friendly_id_slugs USING btree (slug, sluggable_type, scope);


--
-- Name: index_friendly_id_slugs_on_sluggable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_id ON public.friendly_id_slugs USING btree (sluggable_id);


--
-- Name: index_friendly_id_slugs_on_sluggable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_friendly_id_slugs_on_sluggable_type ON public.friendly_id_slugs USING btree (sluggable_type);


--
-- Name: index_heb412_gen_doc_on_tdoc_type_and_tdoc_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_heb412_gen_doc_on_tdoc_type_and_tdoc_id ON public.heb412_gen_doc USING btree (tdoc_type, tdoc_id);


--
-- Name: index_inventory_units_on_shipment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_units_on_shipment_id ON public.spree_inventory_units USING btree (shipment_id);


--
-- Name: index_inventory_units_on_variant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_inventory_units_on_variant_id ON public.spree_inventory_units USING btree (variant_id);


--
-- Name: index_mr519_gen_encuestapersona_on_adurl; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mr519_gen_encuestapersona_on_adurl ON public.mr519_gen_encuestapersona USING btree (adurl);


--
-- Name: index_option_values_variants_on_variant_id_and_option_value_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_option_values_variants_on_variant_id_and_option_value_id ON public.spree_option_values_variants USING btree (variant_id, option_value_id);


--
-- Name: index_product_properties_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_product_properties_on_product_id ON public.spree_product_properties USING btree (product_id);


--
-- Name: index_products_promotion_rules_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_promotion_rules_on_product_id ON public.spree_product_promotion_rules USING btree (product_id);


--
-- Name: index_products_promotion_rules_on_promotion_rule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_products_promotion_rules_on_promotion_rule_id ON public.spree_product_promotion_rules USING btree (promotion_rule_id);


--
-- Name: index_promotion_rules_on_product_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_promotion_rules_on_product_group_id ON public.spree_promotion_rules USING btree (product_group_id);


--
-- Name: index_promotion_rules_users_on_promotion_rule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_promotion_rules_users_on_promotion_rule_id ON public.spree_promotion_rules_users USING btree (promotion_rule_id);


--
-- Name: index_promotion_rules_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_promotion_rules_users_on_user_id ON public.spree_promotion_rules_users USING btree (user_id);


--
-- Name: index_refunds_on_refund_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_refund_reason_id ON public.spree_refunds USING btree (refund_reason_id);


--
-- Name: index_return_authorizations_on_return_authorization_reason_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_return_authorizations_on_return_authorization_reason_id ON public.spree_return_authorizations USING btree (return_reason_id);


--
-- Name: index_return_items_on_customer_return_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_return_items_on_customer_return_id ON public.spree_return_items USING btree (customer_return_id);


--
-- Name: index_shipments_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shipments_on_number ON public.spree_shipments USING btree (number);


--
-- Name: index_sip_orgsocial_on_grupoper_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sip_orgsocial_on_grupoper_id ON public.sip_orgsocial USING btree (grupoper_id);


--
-- Name: index_sip_orgsocial_on_pais_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sip_orgsocial_on_pais_id ON public.sip_orgsocial USING btree (pais_id);


--
-- Name: index_sip_ubicacion_on_id_clase; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sip_ubicacion_on_id_clase ON public.sip_ubicacion USING btree (id_clase);


--
-- Name: index_sip_ubicacion_on_id_departamento; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sip_ubicacion_on_id_departamento ON public.sip_ubicacion USING btree (id_departamento);


--
-- Name: index_sip_ubicacion_on_id_municipio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sip_ubicacion_on_id_municipio ON public.sip_ubicacion USING btree (id_municipio);


--
-- Name: index_sip_ubicacion_on_id_pais; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sip_ubicacion_on_id_pais ON public.sip_ubicacion USING btree (id_pais);


--
-- Name: index_sivel2_gen_antecedente_combatiente_on_id_antecedente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sivel2_gen_antecedente_combatiente_on_id_antecedente ON public.sivel2_gen_antecedente_combatiente USING btree (id_antecedente);


--
-- Name: index_sivel2_gen_antecedente_combatiente_on_id_combatiente; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sivel2_gen_antecedente_combatiente_on_id_combatiente ON public.sivel2_gen_antecedente_combatiente USING btree (id_combatiente);


--
-- Name: index_sivel2_gen_contextovictima_victima_on_contextovictima_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sivel2_gen_contextovictima_victima_on_contextovictima_id ON public.sivel2_gen_contextovictima_victima USING btree (contextovictima_id);


--
-- Name: index_sivel2_gen_contextovictima_victima_on_victima_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sivel2_gen_contextovictima_victima_on_victima_id ON public.sivel2_gen_contextovictima_victima USING btree (victima_id);


--
-- Name: index_sivel2_gen_etnia_victimacolectiva_on_etnia_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sivel2_gen_etnia_victimacolectiva_on_etnia_id ON public.sivel2_gen_etnia_victimacolectiva USING btree (etnia_id);


--
-- Name: index_sivel2_gen_etnia_victimacolectiva_on_victimacolectiva_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sivel2_gen_etnia_victimacolectiva_on_victimacolectiva_id ON public.sivel2_gen_etnia_victimacolectiva USING btree (victimacolectiva_id);


--
-- Name: index_sivel2_gen_sectorsocialsec_victima_on_sectorsocial_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sivel2_gen_sectorsocialsec_victima_on_sectorsocial_id ON public.sivel2_gen_sectorsocialsec_victima USING btree (sectorsocial_id);


--
-- Name: index_sivel2_gen_sectorsocialsec_victima_on_victima_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sivel2_gen_sectorsocialsec_victima_on_victima_id ON public.sivel2_gen_sectorsocialsec_victima USING btree (victima_id);


--
-- Name: index_spree_addresses_on_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_addresses_on_country_id ON public.spree_addresses USING btree (country_id);


--
-- Name: index_spree_addresses_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_addresses_on_name ON public.spree_addresses USING btree (name);


--
-- Name: index_spree_addresses_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_addresses_on_state_id ON public.spree_addresses USING btree (state_id);


--
-- Name: index_spree_adjustment_reasons_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_adjustment_reasons_on_active ON public.spree_adjustment_reasons USING btree (active);


--
-- Name: index_spree_adjustment_reasons_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_adjustment_reasons_on_code ON public.spree_adjustment_reasons USING btree (code);


--
-- Name: index_spree_adjustments_on_adjustable_id_and_adjustable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_adjustments_on_adjustable_id_and_adjustable_type ON public.spree_adjustments USING btree (adjustable_id, adjustable_type);


--
-- Name: index_spree_adjustments_on_eligible; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_adjustments_on_eligible ON public.spree_adjustments USING btree (eligible);


--
-- Name: index_spree_adjustments_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_adjustments_on_order_id ON public.spree_adjustments USING btree (order_id);


--
-- Name: index_spree_adjustments_on_promotion_code_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_adjustments_on_promotion_code_id ON public.spree_adjustments USING btree (promotion_code_id);


--
-- Name: index_spree_adjustments_on_source_id_and_source_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_adjustments_on_source_id_and_source_type ON public.spree_adjustments USING btree (source_id, source_type);


--
-- Name: index_spree_calculators_on_calculable_id_and_calculable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_calculators_on_calculable_id_and_calculable_type ON public.spree_calculators USING btree (calculable_id, calculable_type);


--
-- Name: index_spree_calculators_on_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_calculators_on_id_and_type ON public.spree_calculators USING btree (id, type);


--
-- Name: index_spree_cartons_on_external_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_cartons_on_external_number ON public.spree_cartons USING btree (external_number);


--
-- Name: index_spree_cartons_on_imported_from_shipment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_cartons_on_imported_from_shipment_id ON public.spree_cartons USING btree (imported_from_shipment_id);


--
-- Name: index_spree_cartons_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_cartons_on_number ON public.spree_cartons USING btree (number);


--
-- Name: index_spree_cartons_on_stock_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_cartons_on_stock_location_id ON public.spree_cartons USING btree (stock_location_id);


--
-- Name: index_spree_countries_on_iso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_countries_on_iso ON public.spree_countries USING btree (iso);


--
-- Name: index_spree_credit_cards_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_credit_cards_on_payment_method_id ON public.spree_credit_cards USING btree (payment_method_id);


--
-- Name: index_spree_credit_cards_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_credit_cards_on_user_id ON public.spree_credit_cards USING btree (user_id);


--
-- Name: index_spree_inventory_units_on_carton_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_inventory_units_on_carton_id ON public.spree_inventory_units USING btree (carton_id);


--
-- Name: index_spree_inventory_units_on_line_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_inventory_units_on_line_item_id ON public.spree_inventory_units USING btree (line_item_id);


--
-- Name: index_spree_line_item_actions_on_action_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_line_item_actions_on_action_id ON public.spree_line_item_actions USING btree (action_id);


--
-- Name: index_spree_line_item_actions_on_line_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_line_item_actions_on_line_item_id ON public.spree_line_item_actions USING btree (line_item_id);


--
-- Name: index_spree_line_items_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_line_items_on_order_id ON public.spree_line_items USING btree (order_id);


--
-- Name: index_spree_line_items_on_variant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_line_items_on_variant_id ON public.spree_line_items USING btree (variant_id);


--
-- Name: index_spree_log_entries_on_source_id_and_source_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_log_entries_on_source_id_and_source_type ON public.spree_log_entries USING btree (source_id, source_type);


--
-- Name: index_spree_option_types_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_option_types_on_position ON public.spree_option_types USING btree ("position");


--
-- Name: index_spree_option_values_on_option_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_option_values_on_option_type_id ON public.spree_option_values USING btree (option_type_id);


--
-- Name: index_spree_option_values_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_option_values_on_position ON public.spree_option_values USING btree ("position");


--
-- Name: index_spree_option_values_variants_on_variant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_option_values_variants_on_variant_id ON public.spree_option_values_variants USING btree (variant_id);


--
-- Name: index_spree_order_mutexes_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_order_mutexes_on_order_id ON public.spree_order_mutexes USING btree (order_id);


--
-- Name: index_spree_orders_on_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_approver_id ON public.spree_orders USING btree (approver_id);


--
-- Name: index_spree_orders_on_bill_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_bill_address_id ON public.spree_orders USING btree (bill_address_id);


--
-- Name: index_spree_orders_on_completed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_completed_at ON public.spree_orders USING btree (completed_at);


--
-- Name: index_spree_orders_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_created_by_id ON public.spree_orders USING btree (created_by_id);


--
-- Name: index_spree_orders_on_guest_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_guest_token ON public.spree_orders USING btree (guest_token);


--
-- Name: index_spree_orders_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_number ON public.spree_orders USING btree (number);


--
-- Name: index_spree_orders_on_ship_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_ship_address_id ON public.spree_orders USING btree (ship_address_id);


--
-- Name: index_spree_orders_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_user_id ON public.spree_orders USING btree (user_id);


--
-- Name: index_spree_orders_on_user_id_and_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_on_user_id_and_created_by_id ON public.spree_orders USING btree (user_id, created_by_id);


--
-- Name: index_spree_orders_promotions_on_order_id_and_promotion_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_promotions_on_order_id_and_promotion_id ON public.spree_orders_promotions USING btree (order_id, promotion_id);


--
-- Name: index_spree_orders_promotions_on_promotion_code_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_orders_promotions_on_promotion_code_id ON public.spree_orders_promotions USING btree (promotion_code_id);


--
-- Name: index_spree_payment_capture_events_on_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_payment_capture_events_on_payment_id ON public.spree_payment_capture_events USING btree (payment_id);


--
-- Name: index_spree_payment_methods_on_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_payment_methods_on_id_and_type ON public.spree_payment_methods USING btree (id, type);


--
-- Name: index_spree_payments_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_payments_on_number ON public.spree_payments USING btree (number);


--
-- Name: index_spree_payments_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_payments_on_order_id ON public.spree_payments USING btree (order_id);


--
-- Name: index_spree_payments_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_payments_on_payment_method_id ON public.spree_payments USING btree (payment_method_id);


--
-- Name: index_spree_payments_on_source_id_and_source_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_payments_on_source_id_and_source_type ON public.spree_payments USING btree (source_id, source_type);


--
-- Name: index_spree_preferences_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_preferences_on_key ON public.spree_preferences USING btree (key);


--
-- Name: index_spree_prices_on_country_iso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_prices_on_country_iso ON public.spree_prices USING btree (country_iso);


--
-- Name: index_spree_prices_on_variant_id_and_currency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_prices_on_variant_id_and_currency ON public.spree_prices USING btree (variant_id, currency);


--
-- Name: index_spree_product_option_types_on_option_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_product_option_types_on_option_type_id ON public.spree_product_option_types USING btree (option_type_id);


--
-- Name: index_spree_product_option_types_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_product_option_types_on_position ON public.spree_product_option_types USING btree ("position");


--
-- Name: index_spree_product_option_types_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_product_option_types_on_product_id ON public.spree_product_option_types USING btree (product_id);


--
-- Name: index_spree_product_properties_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_product_properties_on_position ON public.spree_product_properties USING btree ("position");


--
-- Name: index_spree_product_properties_on_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_product_properties_on_property_id ON public.spree_product_properties USING btree (property_id);


--
-- Name: index_spree_products_on_available_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_products_on_available_on ON public.spree_products USING btree (available_on);


--
-- Name: index_spree_products_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_products_on_deleted_at ON public.spree_products USING btree (deleted_at);


--
-- Name: index_spree_products_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_products_on_name ON public.spree_products USING btree (name);


--
-- Name: index_spree_products_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_products_on_slug ON public.spree_products USING btree (slug);


--
-- Name: index_spree_products_taxons_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_products_taxons_on_position ON public.spree_products_taxons USING btree ("position");


--
-- Name: index_spree_products_taxons_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_products_taxons_on_product_id ON public.spree_products_taxons USING btree (product_id);


--
-- Name: index_spree_products_taxons_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_products_taxons_on_taxon_id ON public.spree_products_taxons USING btree (taxon_id);


--
-- Name: index_spree_promotion_action_line_items_on_promotion_action_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_action_line_items_on_promotion_action_id ON public.spree_promotion_action_line_items USING btree (promotion_action_id);


--
-- Name: index_spree_promotion_action_line_items_on_variant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_action_line_items_on_variant_id ON public.spree_promotion_action_line_items USING btree (variant_id);


--
-- Name: index_spree_promotion_actions_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_actions_on_deleted_at ON public.spree_promotion_actions USING btree (deleted_at);


--
-- Name: index_spree_promotion_actions_on_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_actions_on_id_and_type ON public.spree_promotion_actions USING btree (id, type);


--
-- Name: index_spree_promotion_actions_on_promotion_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_actions_on_promotion_id ON public.spree_promotion_actions USING btree (promotion_id);


--
-- Name: index_spree_promotion_code_batches_on_promotion_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_code_batches_on_promotion_id ON public.spree_promotion_code_batches USING btree (promotion_id);


--
-- Name: index_spree_promotion_codes_on_promotion_code_batch_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_codes_on_promotion_code_batch_id ON public.spree_promotion_codes USING btree (promotion_code_batch_id);


--
-- Name: index_spree_promotion_codes_on_promotion_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_codes_on_promotion_id ON public.spree_promotion_codes USING btree (promotion_id);


--
-- Name: index_spree_promotion_codes_on_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_promotion_codes_on_value ON public.spree_promotion_codes USING btree (value);


--
-- Name: index_spree_promotion_rule_taxons_on_promotion_rule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_rule_taxons_on_promotion_rule_id ON public.spree_promotion_rule_taxons USING btree (promotion_rule_id);


--
-- Name: index_spree_promotion_rule_taxons_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_rule_taxons_on_taxon_id ON public.spree_promotion_rule_taxons USING btree (taxon_id);


--
-- Name: index_spree_promotion_rules_on_promotion_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_rules_on_promotion_id ON public.spree_promotion_rules USING btree (promotion_id);


--
-- Name: index_spree_promotion_rules_stores_on_promotion_rule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_rules_stores_on_promotion_rule_id ON public.spree_promotion_rules_stores USING btree (promotion_rule_id);


--
-- Name: index_spree_promotion_rules_stores_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotion_rules_stores_on_store_id ON public.spree_promotion_rules_stores USING btree (store_id);


--
-- Name: index_spree_promotions_on_advertise; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotions_on_advertise ON public.spree_promotions USING btree (advertise);


--
-- Name: index_spree_promotions_on_apply_automatically; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotions_on_apply_automatically ON public.spree_promotions USING btree (apply_automatically);


--
-- Name: index_spree_promotions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotions_on_expires_at ON public.spree_promotions USING btree (expires_at);


--
-- Name: index_spree_promotions_on_id_and_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotions_on_id_and_type ON public.spree_promotions USING btree (id, type);


--
-- Name: index_spree_promotions_on_promotion_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotions_on_promotion_category_id ON public.spree_promotions USING btree (promotion_category_id);


--
-- Name: index_spree_promotions_on_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_promotions_on_starts_at ON public.spree_promotions USING btree (starts_at);


--
-- Name: index_spree_prototype_taxons_on_prototype_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_prototype_taxons_on_prototype_id ON public.spree_prototype_taxons USING btree (prototype_id);


--
-- Name: index_spree_prototype_taxons_on_taxon_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_prototype_taxons_on_taxon_id ON public.spree_prototype_taxons USING btree (taxon_id);


--
-- Name: index_spree_refunds_on_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_refunds_on_payment_id ON public.spree_refunds USING btree (payment_id);


--
-- Name: index_spree_refunds_on_reimbursement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_refunds_on_reimbursement_id ON public.spree_refunds USING btree (reimbursement_id);


--
-- Name: index_spree_reimbursement_types_on_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_reimbursement_types_on_type ON public.spree_reimbursement_types USING btree (type);


--
-- Name: index_spree_reimbursements_on_customer_return_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_reimbursements_on_customer_return_id ON public.spree_reimbursements USING btree (customer_return_id);


--
-- Name: index_spree_reimbursements_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_reimbursements_on_order_id ON public.spree_reimbursements USING btree (order_id);


--
-- Name: index_spree_return_items_on_exchange_inventory_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_return_items_on_exchange_inventory_unit_id ON public.spree_return_items USING btree (exchange_inventory_unit_id);


--
-- Name: index_spree_roles_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_roles_on_name ON public.spree_roles USING btree (name);


--
-- Name: index_spree_roles_users_on_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_roles_users_on_role_id ON public.spree_roles_users USING btree (role_id);


--
-- Name: index_spree_roles_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_roles_users_on_user_id ON public.spree_roles_users USING btree (user_id);


--
-- Name: index_spree_roles_users_on_user_id_and_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_roles_users_on_user_id_and_role_id ON public.spree_roles_users USING btree (user_id, role_id);


--
-- Name: index_spree_shipments_on_deprecated_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_shipments_on_deprecated_address_id ON public.spree_shipments USING btree (deprecated_address_id);


--
-- Name: index_spree_shipments_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_shipments_on_order_id ON public.spree_shipments USING btree (order_id);


--
-- Name: index_spree_shipments_on_stock_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_shipments_on_stock_location_id ON public.spree_shipments USING btree (stock_location_id);


--
-- Name: index_spree_shipping_method_categories_on_shipping_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_shipping_method_categories_on_shipping_method_id ON public.spree_shipping_method_categories USING btree (shipping_method_id);


--
-- Name: index_spree_shipping_methods_on_tax_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_shipping_methods_on_tax_category_id ON public.spree_shipping_methods USING btree (tax_category_id);


--
-- Name: index_spree_shipping_rate_taxes_on_shipping_rate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_shipping_rate_taxes_on_shipping_rate_id ON public.spree_shipping_rate_taxes USING btree (shipping_rate_id);


--
-- Name: index_spree_shipping_rate_taxes_on_tax_rate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_shipping_rate_taxes_on_tax_rate_id ON public.spree_shipping_rate_taxes USING btree (tax_rate_id);


--
-- Name: index_spree_state_changes_on_stateful_id_and_stateful_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_state_changes_on_stateful_id_and_stateful_type ON public.spree_state_changes USING btree (stateful_id, stateful_type);


--
-- Name: index_spree_state_changes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_state_changes_on_user_id ON public.spree_state_changes USING btree (user_id);


--
-- Name: index_spree_states_on_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_states_on_country_id ON public.spree_states USING btree (country_id);


--
-- Name: index_spree_stock_items_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_stock_items_on_deleted_at ON public.spree_stock_items USING btree (deleted_at);


--
-- Name: index_spree_stock_items_on_stock_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_stock_items_on_stock_location_id ON public.spree_stock_items USING btree (stock_location_id);


--
-- Name: index_spree_stock_items_on_variant_id_and_stock_location_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_stock_items_on_variant_id_and_stock_location_id ON public.spree_stock_items USING btree (variant_id, stock_location_id) WHERE (deleted_at IS NULL);


--
-- Name: index_spree_stock_locations_on_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_stock_locations_on_country_id ON public.spree_stock_locations USING btree (country_id);


--
-- Name: index_spree_stock_locations_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_stock_locations_on_state_id ON public.spree_stock_locations USING btree (state_id);


--
-- Name: index_spree_stock_movements_on_stock_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_stock_movements_on_stock_item_id ON public.spree_stock_movements USING btree (stock_item_id);


--
-- Name: index_spree_store_credit_events_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_credit_events_on_deleted_at ON public.spree_store_credit_events USING btree (deleted_at);


--
-- Name: index_spree_store_credit_events_on_store_credit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_credit_events_on_store_credit_id ON public.spree_store_credit_events USING btree (store_credit_id);


--
-- Name: index_spree_store_credit_types_on_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_credit_types_on_priority ON public.spree_store_credit_types USING btree (priority);


--
-- Name: index_spree_store_credits_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_credits_on_deleted_at ON public.spree_store_credits USING btree (deleted_at);


--
-- Name: index_spree_store_credits_on_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_credits_on_type_id ON public.spree_store_credits USING btree (type_id);


--
-- Name: index_spree_store_credits_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_credits_on_user_id ON public.spree_store_credits USING btree (user_id);


--
-- Name: index_spree_store_payment_methods_on_payment_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_payment_methods_on_payment_method_id ON public.spree_store_payment_methods USING btree (payment_method_id);


--
-- Name: index_spree_store_payment_methods_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_payment_methods_on_store_id ON public.spree_store_payment_methods USING btree (store_id);


--
-- Name: index_spree_store_shipping_methods_on_shipping_method_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_shipping_methods_on_shipping_method_id ON public.spree_store_shipping_methods USING btree (shipping_method_id);


--
-- Name: index_spree_store_shipping_methods_on_store_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_store_shipping_methods_on_store_id ON public.spree_store_shipping_methods USING btree (store_id);


--
-- Name: index_spree_stores_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_stores_on_code ON public.spree_stores USING btree (code);


--
-- Name: index_spree_stores_on_default; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_stores_on_default ON public.spree_stores USING btree ("default");


--
-- Name: index_spree_tax_rate_tax_categories_on_tax_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_tax_rate_tax_categories_on_tax_category_id ON public.spree_tax_rate_tax_categories USING btree (tax_category_id);


--
-- Name: index_spree_tax_rate_tax_categories_on_tax_rate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_tax_rate_tax_categories_on_tax_rate_id ON public.spree_tax_rate_tax_categories USING btree (tax_rate_id);


--
-- Name: index_spree_tax_rates_on_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_tax_rates_on_deleted_at ON public.spree_tax_rates USING btree (deleted_at);


--
-- Name: index_spree_tax_rates_on_zone_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_tax_rates_on_zone_id ON public.spree_tax_rates USING btree (zone_id);


--
-- Name: index_spree_taxonomies_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_taxonomies_on_position ON public.spree_taxonomies USING btree ("position");


--
-- Name: index_spree_taxons_on_lft; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_taxons_on_lft ON public.spree_taxons USING btree (lft);


--
-- Name: index_spree_taxons_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_taxons_on_position ON public.spree_taxons USING btree ("position");


--
-- Name: index_spree_taxons_on_rgt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_taxons_on_rgt ON public.spree_taxons USING btree (rgt);


--
-- Name: index_spree_unit_cancels_on_inventory_unit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_unit_cancels_on_inventory_unit_id ON public.spree_unit_cancels USING btree (inventory_unit_id);


--
-- Name: index_spree_user_addresses_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_user_addresses_on_address_id ON public.spree_user_addresses USING btree (address_id);


--
-- Name: index_spree_user_addresses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_user_addresses_on_user_id ON public.spree_user_addresses USING btree (user_id);


--
-- Name: index_spree_user_addresses_on_user_id_and_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_user_addresses_on_user_id_and_address_id ON public.spree_user_addresses USING btree (user_id, address_id);


--
-- Name: index_spree_user_stock_locations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_user_stock_locations_on_user_id ON public.spree_user_stock_locations USING btree (user_id);


--
-- Name: index_spree_users_on_spree_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_users_on_spree_api_key ON public.spree_users USING btree (spree_api_key);


--
-- Name: index_spree_variant_prop_rule_conditions_on_rule_and_optval; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variant_prop_rule_conditions_on_rule_and_optval ON public.spree_variant_property_rule_conditions USING btree (variant_property_rule_id, option_value_id);


--
-- Name: index_spree_variant_property_rule_values_on_property_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variant_property_rule_values_on_property_id ON public.spree_variant_property_rule_values USING btree (property_id);


--
-- Name: index_spree_variant_property_rule_values_on_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variant_property_rule_values_on_rule ON public.spree_variant_property_rule_values USING btree (variant_property_rule_id);


--
-- Name: index_spree_variant_property_rules_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variant_property_rules_on_product_id ON public.spree_variant_property_rules USING btree (product_id);


--
-- Name: index_spree_variants_on_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variants_on_position ON public.spree_variants USING btree ("position");


--
-- Name: index_spree_variants_on_product_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variants_on_product_id ON public.spree_variants USING btree (product_id);


--
-- Name: index_spree_variants_on_sku; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variants_on_sku ON public.spree_variants USING btree (sku);


--
-- Name: index_spree_variants_on_tax_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variants_on_tax_category_id ON public.spree_variants USING btree (tax_category_id);


--
-- Name: index_spree_variants_on_track_inventory; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_variants_on_track_inventory ON public.spree_variants USING btree (track_inventory);


--
-- Name: index_spree_wallet_payment_sources_on_source_and_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_spree_wallet_payment_sources_on_source_and_user ON public.spree_wallet_payment_sources USING btree (user_id, payment_source_id, payment_source_type);


--
-- Name: index_spree_wallet_payment_sources_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_wallet_payment_sources_on_user_id ON public.spree_wallet_payment_sources USING btree (user_id);


--
-- Name: index_spree_zone_members_on_zone_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_zone_members_on_zone_id ON public.spree_zone_members USING btree (zone_id);


--
-- Name: index_spree_zone_members_on_zoneable_id_and_zoneable_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_spree_zone_members_on_zoneable_id_and_zoneable_type ON public.spree_zone_members USING btree (zoneable_id, zoneable_type);


--
-- Name: index_taxons_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxons_on_parent_id ON public.spree_taxons USING btree (parent_id);


--
-- Name: index_taxons_on_permalink; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxons_on_permalink ON public.spree_taxons USING btree (permalink);


--
-- Name: index_taxons_on_taxonomy_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_taxons_on_taxonomy_id ON public.spree_taxons USING btree (taxonomy_id);


--
-- Name: index_usuario_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usuario_on_email ON public.usuario USING btree (email);


--
-- Name: index_usuario_on_regionsjr_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_usuario_on_regionsjr_id ON public.usuario USING btree (oficina_id);


--
-- Name: index_usuario_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_usuario_on_reset_password_token ON public.usuario USING btree (reset_password_token);


--
-- Name: indice_sip_ubicacion_sobre_id_caso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sip_ubicacion_sobre_id_caso ON public.sip_ubicacion USING btree (id_caso);


--
-- Name: indice_sivel2_gen_acto_sobre_id_caso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_acto_sobre_id_caso ON public.sivel2_gen_acto USING btree (id_caso);


--
-- Name: indice_sivel2_gen_acto_sobre_id_categoria; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_acto_sobre_id_categoria ON public.sivel2_gen_acto USING btree (id_categoria);


--
-- Name: indice_sivel2_gen_acto_sobre_id_persona; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_acto_sobre_id_persona ON public.sivel2_gen_acto USING btree (id_persona);


--
-- Name: indice_sivel2_gen_acto_sobre_id_presponsable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_acto_sobre_id_presponsable ON public.sivel2_gen_acto USING btree (id_presponsable);


--
-- Name: indice_sivel2_gen_caso_presponsable_sobre_id_caso; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_caso_presponsable_sobre_id_caso ON public.sivel2_gen_caso_presponsable USING btree (id_caso);


--
-- Name: indice_sivel2_gen_caso_presponsable_sobre_id_presponsable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_caso_presponsable_sobre_id_presponsable ON public.sivel2_gen_caso_presponsable USING btree (id_presponsable);


--
-- Name: indice_sivel2_gen_caso_presponsable_sobre_ids_caso_presp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_caso_presponsable_sobre_ids_caso_presp ON public.sivel2_gen_caso_presponsable USING btree (id_caso, id_presponsable);


--
-- Name: indice_sivel2_gen_caso_sobre_fecha; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_caso_sobre_fecha ON public.sivel2_gen_caso USING btree (fecha);


--
-- Name: indice_sivel2_gen_caso_sobre_ubicacion_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_caso_sobre_ubicacion_id ON public.sivel2_gen_caso USING btree (ubicacion_id);


--
-- Name: indice_sivel2_gen_categoria_sobre_supracategoria_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX indice_sivel2_gen_categoria_sobre_supracategoria_id ON public.sivel2_gen_categoria USING btree (supracategoria_id);


--
-- Name: shipping_method_id_spree_sm_sl; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX shipping_method_id_spree_sm_sl ON public.spree_shipping_method_stock_locations USING btree (shipping_method_id);


--
-- Name: sip_busca_mundep; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sip_busca_mundep ON public.sip_mundep USING gin (mundep);


--
-- Name: sip_nombre_ubicacionpre_b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sip_nombre_ubicacionpre_b ON public.sip_ubicacionpre USING gin (to_tsvector('spanish'::regconfig, public.f_unaccent((nombre)::text)));


--
-- Name: sivel2_gen_obs_fildep_d_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sivel2_gen_obs_fildep_d_idx ON public.sivel2_gen_observador_filtrodepartamento USING btree (departamento_id);


--
-- Name: sivel2_gen_obs_fildep_u_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sivel2_gen_obs_fildep_u_idx ON public.sivel2_gen_observador_filtrodepartamento USING btree (usuario_id);


--
-- Name: spree_shipping_rates_join_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX spree_shipping_rates_join_index ON public.spree_shipping_rates USING btree (shipment_id, shipping_method_id);


--
-- Name: sstock_location_id_spree_sm_sl; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sstock_location_id_spree_sm_sl ON public.spree_shipping_method_stock_locations USING btree (stock_location_id);


--
-- Name: stock_item_by_loc_and_var_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX stock_item_by_loc_and_var_id ON public.spree_stock_items USING btree (stock_location_id, variant_id);


--
-- Name: unique_spree_shipping_method_categories; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_spree_shipping_method_categories ON public.spree_shipping_method_categories USING btree (shipping_category_id, shipping_method_id);


--
-- Name: usuario_nusuario; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX usuario_nusuario ON public.usuario USING btree (nusuario);


--
-- Name: sivel2_gen_supracategoria $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_supracategoria
    ADD CONSTRAINT "$1" FOREIGN KEY (id_tviolencia) REFERENCES public.sivel2_gen_tviolencia(id);


--
-- Name: sivel2_gen_victimacolectiva $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva
    ADD CONSTRAINT "$1" FOREIGN KEY (organizacionarmada) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sivel2_gen_antecedente_victimacolectiva $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente_victimacolectiva
    ADD CONSTRAINT "$1" FOREIGN KEY (id_antecedente) REFERENCES public.sivel2_gen_antecedente(id);


--
-- Name: sivel2_gen_filiacion_victimacolectiva $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_filiacion_victimacolectiva
    ADD CONSTRAINT "$1" FOREIGN KEY (id_filiacion) REFERENCES public.sivel2_gen_filiacion(id);


--
-- Name: sivel2_gen_rangoedad_victimacolectiva $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_rangoedad_victimacolectiva
    ADD CONSTRAINT "$1" FOREIGN KEY (id_rangoedad) REFERENCES public.sivel2_gen_rangoedad(id);


--
-- Name: sivel2_gen_sectorsocial_victimacolectiva $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_sectorsocial_victimacolectiva
    ADD CONSTRAINT "$1" FOREIGN KEY (id_sectorsocial) REFERENCES public.sivel2_gen_sectorsocial(id);


--
-- Name: sivel2_gen_victimacolectiva_vinculoestado $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva_vinculoestado
    ADD CONSTRAINT "$1" FOREIGN KEY (id_vinculoestado) REFERENCES public.sivel2_gen_vinculoestado(id);


--
-- Name: sivel2_gen_profesion_victimacolectiva $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_profesion_victimacolectiva
    ADD CONSTRAINT "$1" FOREIGN KEY (id_profesion) REFERENCES public.sivel2_gen_profesion(id);


--
-- Name: sivel2_gen_caso $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso
    ADD CONSTRAINT "$1" FOREIGN KEY (id_intervalo) REFERENCES public.sivel2_gen_intervalo(id);


--
-- Name: sivel2_gen_antecedente_caso $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente_caso
    ADD CONSTRAINT "$1" FOREIGN KEY (id_antecedente) REFERENCES public.sivel2_gen_antecedente(id);


--
-- Name: sivel2_gen_caso_contexto $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_contexto
    ADD CONSTRAINT "$1" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_caso_presponsable $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_presponsable
    ADD CONSTRAINT "$1" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_caso_frontera $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_frontera
    ADD CONSTRAINT "$1" FOREIGN KEY (id_frontera) REFERENCES public.sivel2_gen_frontera(id);


--
-- Name: sivel2_gen_organizacion_victimacolectiva $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_organizacion_victimacolectiva
    ADD CONSTRAINT "$1" FOREIGN KEY (id_organizacion) REFERENCES public.sivel2_gen_organizacion(id);


--
-- Name: sivel2_gen_caso_region $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_region
    ADD CONSTRAINT "$1" FOREIGN KEY (id_region) REFERENCES public.sivel2_gen_region(id);


--
-- Name: sivel2_gen_victima $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT "$1" FOREIGN KEY (id_profesion) REFERENCES public.sivel2_gen_profesion(id);


--
-- Name: sivel2_gen_antecedente_victima $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente_victima
    ADD CONSTRAINT "$1" FOREIGN KEY (id_antecedente) REFERENCES public.sivel2_gen_antecedente(id);


--
-- Name: sivel2_gen_caso_fuenteprensa $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fuenteprensa
    ADD CONSTRAINT "$1" FOREIGN KEY (fuenteprensa_id) REFERENCES public.sip_fuenteprensa(id);


--
-- Name: sivel2_gen_caso_fotra $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fotra
    ADD CONSTRAINT "$1" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sip_clase $1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_clase
    ADD CONSTRAINT "$1" FOREIGN KEY (id_tclase) REFERENCES public.sip_tclase(id);


--
-- Name: sivel2_gen_antecedente_caso $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente_caso
    ADD CONSTRAINT "$2" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_caso_contexto $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_contexto
    ADD CONSTRAINT "$2" FOREIGN KEY (id_contexto) REFERENCES public.sivel2_gen_contexto(id);


--
-- Name: sivel2_gen_caso_presponsable $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_presponsable
    ADD CONSTRAINT "$2" FOREIGN KEY (id_presponsable) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sivel2_gen_caso_categoria_presponsable $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_categoria_presponsable
    ADD CONSTRAINT "$2" FOREIGN KEY (id_categoria) REFERENCES public.sivel2_gen_categoria(id);


--
-- Name: sivel2_gen_caso_frontera $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_frontera
    ADD CONSTRAINT "$2" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_caso_region $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_region
    ADD CONSTRAINT "$2" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_victima $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT "$2" FOREIGN KEY (id_rangoedad) REFERENCES public.sivel2_gen_rangoedad(id);


--
-- Name: sivel2_gen_caso_usuario $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_usuario
    ADD CONSTRAINT "$2" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_caso_fuenteprensa $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fuenteprensa
    ADD CONSTRAINT "$2" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_caso_fotra $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fotra
    ADD CONSTRAINT "$2" FOREIGN KEY (id_fotra) REFERENCES public.sivel2_gen_fotra(id);


--
-- Name: antecedente_combatiente $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.antecedente_combatiente
    ADD CONSTRAINT "$2" FOREIGN KEY (id_combatiente) REFERENCES public.combatiente(id);


--
-- Name: combatiente_presponsable $2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.combatiente_presponsable
    ADD CONSTRAINT "$2" FOREIGN KEY (id_combatiente) REFERENCES public.combatiente(id);


--
-- Name: sivel2_gen_victima $3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT "$3" FOREIGN KEY (id_filiacion) REFERENCES public.sivel2_gen_filiacion(id);


--
-- Name: sivel2_gen_victima $4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT "$4" FOREIGN KEY (id_sectorsocial) REFERENCES public.sivel2_gen_sectorsocial(id);


--
-- Name: sivel2_gen_victima $5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT "$5" FOREIGN KEY (id_organizacion) REFERENCES public.sivel2_gen_organizacion(id);


--
-- Name: sivel2_gen_victima $6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT "$6" FOREIGN KEY (id_vinculoestado) REFERENCES public.sivel2_gen_vinculoestado(id);


--
-- Name: sivel2_gen_victima $7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT "$7" FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_victima $8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT "$8" FOREIGN KEY (organizacionarmada) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sivel2_gen_acto acto_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_acto
    ADD CONSTRAINT acto_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_acto acto_id_categoria_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_acto
    ADD CONSTRAINT acto_id_categoria_fkey FOREIGN KEY (id_categoria) REFERENCES public.sivel2_gen_categoria(id);


--
-- Name: sivel2_gen_acto acto_id_p_responsable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_acto
    ADD CONSTRAINT acto_id_p_responsable_fkey FOREIGN KEY (id_presponsable) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sivel2_gen_acto acto_id_persona_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_acto
    ADD CONSTRAINT acto_id_persona_fkey FOREIGN KEY (id_persona) REFERENCES public.sip_persona(id);


--
-- Name: sivel2_gen_acto acto_victima_lf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_acto
    ADD CONSTRAINT acto_victima_lf FOREIGN KEY (id_caso, id_persona) REFERENCES public.sivel2_gen_victima(id_caso, id_persona);


--
-- Name: sivel2_gen_actocolectivo actocolectivo_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actocolectivo
    ADD CONSTRAINT actocolectivo_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_actocolectivo actocolectivo_id_categoria_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actocolectivo
    ADD CONSTRAINT actocolectivo_id_categoria_fkey FOREIGN KEY (id_categoria) REFERENCES public.sivel2_gen_categoria(id);


--
-- Name: sivel2_gen_actocolectivo actocolectivo_id_grupoper_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actocolectivo
    ADD CONSTRAINT actocolectivo_id_grupoper_fkey FOREIGN KEY (id_grupoper) REFERENCES public.sip_grupoper(id);


--
-- Name: sivel2_gen_actocolectivo actocolectivo_id_p_responsable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_actocolectivo
    ADD CONSTRAINT actocolectivo_id_p_responsable_fkey FOREIGN KEY (id_presponsable) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sivel2_gen_anexo_caso anexo_fuenteprensa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_anexo_caso
    ADD CONSTRAINT anexo_fuenteprensa_id_fkey FOREIGN KEY (fuenteprensa_id) REFERENCES public.sip_fuenteprensa(id);


--
-- Name: sivel2_gen_anexo_caso anexo_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_anexo_caso
    ADD CONSTRAINT anexo_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_anexo_caso anexo_id_fuente_directa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_anexo_caso
    ADD CONSTRAINT anexo_id_fuente_directa_fkey FOREIGN KEY (id_fotra) REFERENCES public.sivel2_gen_fotra(id);


--
-- Name: sivel2_gen_antecedente_victima antecedente_victima_id_victima_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente_victima
    ADD CONSTRAINT antecedente_victima_id_victima_fkey FOREIGN KEY (id_victima) REFERENCES public.sivel2_gen_victima(id);


--
-- Name: sivel2_gen_caso_categoria_presponsable caso_categoria_presponsable_id_caso_presponsable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_categoria_presponsable
    ADD CONSTRAINT caso_categoria_presponsable_id_caso_presponsable_fkey FOREIGN KEY (id_caso_presponsable) REFERENCES public.sivel2_gen_caso_presponsable(id);


--
-- Name: sivel2_gen_caso_etiqueta caso_etiqueta_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_etiqueta
    ADD CONSTRAINT caso_etiqueta_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id);


--
-- Name: sivel2_gen_caso caso_id_intervalo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso
    ADD CONSTRAINT caso_id_intervalo_fkey FOREIGN KEY (id_intervalo) REFERENCES public.sivel2_gen_intervalo(id);


--
-- Name: sivel2_gen_caso_usuario caso_usuario_id_usuario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_usuario
    ADD CONSTRAINT caso_usuario_id_usuario_fkey FOREIGN KEY (id_usuario) REFERENCES public.usuario(id);


--
-- Name: sivel2_gen_categoria categoria_col_rep_consolidado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_categoria
    ADD CONSTRAINT categoria_col_rep_consolidado_fkey FOREIGN KEY (id_pconsolidado) REFERENCES public.sivel2_gen_pconsolidado(id);


--
-- Name: sivel2_gen_categoria categoria_contada_en_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_categoria
    ADD CONSTRAINT categoria_contada_en_fkey FOREIGN KEY (contadaen) REFERENCES public.sivel2_gen_categoria(id);


--
-- Name: sip_departamento departamento_id_pais_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_departamento
    ADD CONSTRAINT departamento_id_pais_fkey FOREIGN KEY (id_pais) REFERENCES public.sip_pais(id);


--
-- Name: sivel2_gen_caso_etiqueta etiquetacaso_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_etiqueta
    ADD CONSTRAINT etiquetacaso_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_caso_etiqueta etiquetacaso_id_etiqueta_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_etiqueta
    ADD CONSTRAINT etiquetacaso_id_etiqueta_fkey FOREIGN KEY (id_etiqueta) REFERENCES public.sip_etiqueta(id);


--
-- Name: sip_municipio fk_rails_089870a38d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_municipio
    ADD CONSTRAINT fk_rails_089870a38d FOREIGN KEY (id_departamento) REFERENCES public.sip_departamento(id);


--
-- Name: sivel2_gen_sectorsocialsec_victima fk_rails_0feb0e70eb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_sectorsocialsec_victima
    ADD CONSTRAINT fk_rails_0feb0e70eb FOREIGN KEY (sectorsocial_id) REFERENCES public.sivel2_gen_sectorsocial(id);


--
-- Name: sip_etiqueta_municipio fk_rails_10d88626c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_etiqueta_municipio
    ADD CONSTRAINT fk_rails_10d88626c3 FOREIGN KEY (etiqueta_id) REFERENCES public.sip_etiqueta(id);


--
-- Name: sivel2_gen_caso_presponsable fk_rails_118837ae4c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_presponsable
    ADD CONSTRAINT fk_rails_118837ae4c FOREIGN KEY (id_presponsable) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: mr519_gen_encuestausuario fk_rails_1b24d10e82; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestausuario
    ADD CONSTRAINT fk_rails_1b24d10e82 FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: sivel2_gen_contextovictima_victima fk_rails_1b81b1ccd7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_contextovictima_victima
    ADD CONSTRAINT fk_rails_1b81b1ccd7 FOREIGN KEY (contextovictima_id) REFERENCES public.sivel2_gen_contextovictima(id);


--
-- Name: heb412_gen_formulario_plantillahcr fk_rails_1bdf79898c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_formulario_plantillahcr
    ADD CONSTRAINT fk_rails_1bdf79898c FOREIGN KEY (plantillahcr_id) REFERENCES public.heb412_gen_plantillahcr(id);


--
-- Name: heb412_gen_campohc fk_rails_1e5f26c999; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_campohc
    ADD CONSTRAINT fk_rails_1e5f26c999 FOREIGN KEY (doc_id) REFERENCES public.heb412_gen_doc(id);


--
-- Name: mr519_gen_encuestausuario fk_rails_2cb09d778a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestausuario
    ADD CONSTRAINT fk_rails_2cb09d778a FOREIGN KEY (respuestafor_id) REFERENCES public.mr519_gen_respuestafor(id);


--
-- Name: sip_bitacora fk_rails_2db961766c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_bitacora
    ADD CONSTRAINT fk_rails_2db961766c FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: heb412_gen_doc fk_rails_2dd6d3dac3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_doc
    ADD CONSTRAINT fk_rails_2dd6d3dac3 FOREIGN KEY (dirpapa) REFERENCES public.heb412_gen_doc(id);


--
-- Name: sip_ubicacionpre fk_rails_2e86701dfb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacionpre
    ADD CONSTRAINT fk_rails_2e86701dfb FOREIGN KEY (departamento_id) REFERENCES public.sip_departamento(id);


--
-- Name: sivel2_gen_caso_respuestafor fk_rails_3aa0de8b93; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_respuestafor
    ADD CONSTRAINT fk_rails_3aa0de8b93 FOREIGN KEY (caso_id) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sip_ubicacionpre fk_rails_3b59c12090; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacionpre
    ADD CONSTRAINT fk_rails_3b59c12090 FOREIGN KEY (clase_id) REFERENCES public.sip_clase(id);


--
-- Name: spree_tax_rate_tax_categories fk_rails_3e6fe87e12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_tax_rate_tax_categories
    ADD CONSTRAINT fk_rails_3e6fe87e12 FOREIGN KEY (tax_rate_id) REFERENCES public.spree_tax_rates(id);


--
-- Name: sivel2_gen_caso_respuestafor fk_rails_3fd971983e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_respuestafor
    ADD CONSTRAINT fk_rails_3fd971983e FOREIGN KEY (respuestafor_id) REFERENCES public.mr519_gen_respuestafor(id);


--
-- Name: sip_orgsocial_persona fk_rails_4672f6cbcd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial_persona
    ADD CONSTRAINT fk_rails_4672f6cbcd FOREIGN KEY (persona_id) REFERENCES public.sip_persona(id);


--
-- Name: spree_tax_rate_tax_categories fk_rails_499313ce8e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_tax_rate_tax_categories
    ADD CONSTRAINT fk_rails_499313ce8e FOREIGN KEY (tax_category_id) REFERENCES public.spree_tax_categories(id);


--
-- Name: sip_ubicacion fk_rails_4dd7a7f238; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT fk_rails_4dd7a7f238 FOREIGN KEY (id_departamento) REFERENCES public.sip_departamento(id);


--
-- Name: sivel2_gen_etnia_victimacolectiva fk_rails_4fafec807e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_etnia_victimacolectiva
    ADD CONSTRAINT fk_rails_4fafec807e FOREIGN KEY (etnia_id) REFERENCES public.sivel2_gen_etnia(id);


--
-- Name: mr519_gen_encuestapersona fk_rails_54b3e0ed5c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestapersona
    ADD CONSTRAINT fk_rails_54b3e0ed5c FOREIGN KEY (persona_id) REFERENCES public.sip_persona(id);


--
-- Name: sip_etiqueta_municipio fk_rails_5672729520; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_etiqueta_municipio
    ADD CONSTRAINT fk_rails_5672729520 FOREIGN KEY (municipio_id) REFERENCES public.sip_municipio(id);


--
-- Name: sivel2_gen_caso_presponsable fk_rails_5a8abbdd31; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_presponsable
    ADD CONSTRAINT fk_rails_5a8abbdd31 FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sip_orgsocial fk_rails_5b21e3a2af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial
    ADD CONSTRAINT fk_rails_5b21e3a2af FOREIGN KEY (grupoper_id) REFERENCES public.sip_grupoper(id);


--
-- Name: spree_wallet_payment_sources fk_rails_5dd6e027c5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_wallet_payment_sources
    ADD CONSTRAINT fk_rails_5dd6e027c5 FOREIGN KEY (user_id) REFERENCES public.spree_users(id);


--
-- Name: sivel2_gen_contextovictima_victima fk_rails_6322164389; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_contextovictima_victima
    ADD CONSTRAINT fk_rails_6322164389 FOREIGN KEY (victima_id) REFERENCES public.sivel2_gen_victima(id);


--
-- Name: sivel2_gen_combatiente fk_rails_6485d06d37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT fk_rails_6485d06d37 FOREIGN KEY (id_vinculoestado) REFERENCES public.sivel2_gen_vinculoestado(id);


--
-- Name: mr519_gen_opcioncs fk_rails_656b4a3ca7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_opcioncs
    ADD CONSTRAINT fk_rails_656b4a3ca7 FOREIGN KEY (campo_id) REFERENCES public.mr519_gen_campo(id);


--
-- Name: heb412_gen_formulario_plantillahcr fk_rails_696d27d6f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_formulario_plantillahcr
    ADD CONSTRAINT fk_rails_696d27d6f5 FOREIGN KEY (formulario_id) REFERENCES public.mr519_gen_formulario(id);


--
-- Name: heb412_gen_formulario_plantillahcm fk_rails_6e214a7168; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_formulario_plantillahcm
    ADD CONSTRAINT fk_rails_6e214a7168 FOREIGN KEY (formulario_id) REFERENCES public.mr519_gen_formulario(id);


--
-- Name: sip_ubicacion fk_rails_6ed05ed576; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT fk_rails_6ed05ed576 FOREIGN KEY (id_pais) REFERENCES public.sip_pais(id);


--
-- Name: sip_grupo_usuario fk_rails_734ee21e62; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_grupo_usuario
    ADD CONSTRAINT fk_rails_734ee21e62 FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: sip_orgsocial fk_rails_7bc2a60574; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial
    ADD CONSTRAINT fk_rails_7bc2a60574 FOREIGN KEY (pais_id) REFERENCES public.sip_pais(id);


--
-- Name: sip_orgsocial_persona fk_rails_7c335482f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial_persona
    ADD CONSTRAINT fk_rails_7c335482f6 FOREIGN KEY (orgsocial_id) REFERENCES public.sip_orgsocial(id);


--
-- Name: mr519_gen_respuestafor fk_rails_805efe6935; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_respuestafor
    ADD CONSTRAINT fk_rails_805efe6935 FOREIGN KEY (formulario_id) REFERENCES public.mr519_gen_formulario(id);


--
-- Name: mr519_gen_valorcampo fk_rails_819cf17399; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_valorcampo
    ADD CONSTRAINT fk_rails_819cf17399 FOREIGN KEY (campo_id) REFERENCES public.mr519_gen_campo(id);


--
-- Name: mr519_gen_encuestapersona fk_rails_83755e20b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestapersona
    ADD CONSTRAINT fk_rails_83755e20b9 FOREIGN KEY (respuestafor_id) REFERENCES public.mr519_gen_respuestafor(id);


--
-- Name: sivel2_gen_caso fk_rails_850036942a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso
    ADD CONSTRAINT fk_rails_850036942a FOREIGN KEY (ubicacion_id) REFERENCES public.sip_ubicacion(id);


--
-- Name: mr519_gen_encuestapersona fk_rails_88eeb03074; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_encuestapersona
    ADD CONSTRAINT fk_rails_88eeb03074 FOREIGN KEY (formulario_id) REFERENCES public.mr519_gen_formulario(id);


--
-- Name: mr519_gen_valorcampo fk_rails_8bb7650018; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_valorcampo
    ADD CONSTRAINT fk_rails_8bb7650018 FOREIGN KEY (respuestafor_id) REFERENCES public.mr519_gen_respuestafor(id);


--
-- Name: sip_grupo_usuario fk_rails_8d24f7c1c0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_grupo_usuario
    ADD CONSTRAINT fk_rails_8d24f7c1c0 FOREIGN KEY (sip_grupo_id) REFERENCES public.sip_grupo(id);


--
-- Name: sip_departamento fk_rails_92093de1a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_departamento
    ADD CONSTRAINT fk_rails_92093de1a1 FOREIGN KEY (id_pais) REFERENCES public.sip_pais(id);


--
-- Name: sivel2_gen_combatiente fk_rails_95f4a0b8f6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT fk_rails_95f4a0b8f6 FOREIGN KEY (id_profesion) REFERENCES public.sivel2_gen_profesion(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: sip_orgsocial_sectororgsocial fk_rails_9f61a364e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial_sectororgsocial
    ADD CONSTRAINT fk_rails_9f61a364e0 FOREIGN KEY (sectororgsocial_id) REFERENCES public.sip_sectororgsocial(id);


--
-- Name: mr519_gen_campo fk_rails_a186e1a8a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mr519_gen_campo
    ADD CONSTRAINT fk_rails_a186e1a8a0 FOREIGN KEY (formulario_id) REFERENCES public.mr519_gen_formulario(id);


--
-- Name: sip_ubicacion fk_rails_a1d509c79a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT fk_rails_a1d509c79a FOREIGN KEY (id_clase) REFERENCES public.sip_clase(id);


--
-- Name: sivel2_gen_combatiente fk_rails_af43e915a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT fk_rails_af43e915a6 FOREIGN KEY (id_filiacion) REFERENCES public.sivel2_gen_filiacion(id);


--
-- Name: sip_ubicacion fk_rails_b82283d945; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT fk_rails_b82283d945 FOREIGN KEY (id_municipio) REFERENCES public.sip_municipio(id);


--
-- Name: sivel2_gen_etnia_victimacolectiva fk_rails_be1aa8ff16; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_etnia_victimacolectiva
    ADD CONSTRAINT fk_rails_be1aa8ff16 FOREIGN KEY (victimacolectiva_id) REFERENCES public.sivel2_gen_victimacolectiva(id);


--
-- Name: sivel2_gen_combatiente fk_rails_bfb49597e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT fk_rails_bfb49597e1 FOREIGN KEY (organizacionarmada) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sip_ubicacionpre fk_rails_c08a606417; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacionpre
    ADD CONSTRAINT fk_rails_c08a606417 FOREIGN KEY (municipio_id) REFERENCES public.sip_municipio(id);


--
-- Name: spree_promotion_code_batches fk_rails_c217102f50; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_code_batches
    ADD CONSTRAINT fk_rails_c217102f50 FOREIGN KEY (promotion_id) REFERENCES public.spree_promotions(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: sip_ubicacionpre fk_rails_c8024a90df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacionpre
    ADD CONSTRAINT fk_rails_c8024a90df FOREIGN KEY (tsitio_id) REFERENCES public.sip_tsitio(id);


--
-- Name: usuario fk_rails_cc636858ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_rails_cc636858ad FOREIGN KEY (tema_id) REFERENCES public.sip_tema(id);


--
-- Name: sivel2_gen_sectorsocialsec_victima fk_rails_e04ef7c3e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_sectorsocialsec_victima
    ADD CONSTRAINT fk_rails_e04ef7c3e5 FOREIGN KEY (victima_id) REFERENCES public.sivel2_gen_victima(id);


--
-- Name: heb412_gen_campoplantillahcm fk_rails_e0e38e0782; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_campoplantillahcm
    ADD CONSTRAINT fk_rails_e0e38e0782 FOREIGN KEY (plantillahcm_id) REFERENCES public.heb412_gen_plantillahcm(id);


--
-- Name: sivel2_gen_combatiente fk_rails_e2d01a5a99; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT fk_rails_e2d01a5a99 FOREIGN KEY (id_sectorsocial) REFERENCES public.sivel2_gen_sectorsocial(id);


--
-- Name: spree_promotion_codes fk_rails_e306e312d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.spree_promotion_codes
    ADD CONSTRAINT fk_rails_e306e312d9 FOREIGN KEY (promotion_code_batch_id) REFERENCES public.spree_promotion_code_batches(id);


--
-- Name: heb412_gen_carpetaexclusiva fk_rails_ea1add81e6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_carpetaexclusiva
    ADD CONSTRAINT fk_rails_ea1add81e6 FOREIGN KEY (grupo_id) REFERENCES public.sip_grupo(id);


--
-- Name: sip_ubicacionpre fk_rails_eba8cc9124; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacionpre
    ADD CONSTRAINT fk_rails_eba8cc9124 FOREIGN KEY (pais_id) REFERENCES public.sip_pais(id);


--
-- Name: sip_orgsocial_sectororgsocial fk_rails_f032bb21a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_orgsocial_sectororgsocial
    ADD CONSTRAINT fk_rails_f032bb21a6 FOREIGN KEY (orgsocial_id) REFERENCES public.sip_orgsocial(id);


--
-- Name: sivel2_gen_combatiente fk_rails_f0cf2a7bec; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT fk_rails_f0cf2a7bec FOREIGN KEY (id_resagresion) REFERENCES public.sivel2_gen_resagresion(id);


--
-- Name: sivel2_gen_antecedente_combatiente fk_rails_f305297325; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente_combatiente
    ADD CONSTRAINT fk_rails_f305297325 FOREIGN KEY (id_combatiente) REFERENCES public.sivel2_gen_combatiente(id);


--
-- Name: sivel2_gen_combatiente fk_rails_f77dda7a40; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT fk_rails_f77dda7a40 FOREIGN KEY (id_organizacion) REFERENCES public.sivel2_gen_organizacion(id);


--
-- Name: sivel2_gen_combatiente fk_rails_fb02819ec4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_combatiente
    ADD CONSTRAINT fk_rails_fb02819ec4 FOREIGN KEY (id_rangoedad) REFERENCES public.sivel2_gen_rangoedad(id);


--
-- Name: sip_clase fk_rails_fb09f016e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_clase
    ADD CONSTRAINT fk_rails_fb09f016e4 FOREIGN KEY (id_municipio) REFERENCES public.sip_municipio(id);


--
-- Name: sivel2_gen_antecedente_combatiente fk_rails_fc1811169b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente_combatiente
    ADD CONSTRAINT fk_rails_fc1811169b FOREIGN KEY (id_antecedente) REFERENCES public.sivel2_gen_antecedente(id);


--
-- Name: heb412_gen_formulario_plantillahcm fk_rails_fc3149fc44; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.heb412_gen_formulario_plantillahcm
    ADD CONSTRAINT fk_rails_fc3149fc44 FOREIGN KEY (plantillahcm_id) REFERENCES public.heb412_gen_plantillahcm(id);


--
-- Name: sip_persona persona_id_pais_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona
    ADD CONSTRAINT persona_id_pais_fkey FOREIGN KEY (id_pais) REFERENCES public.sip_pais(id);


--
-- Name: sip_persona persona_nacionalde_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona
    ADD CONSTRAINT persona_nacionalde_fkey FOREIGN KEY (nacionalde) REFERENCES public.sip_pais(id);


--
-- Name: sip_persona persona_tdocumento_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona
    ADD CONSTRAINT persona_tdocumento_id_fkey FOREIGN KEY (tdocumento_id) REFERENCES public.sip_tdocumento(id);


--
-- Name: sivel2_gen_caso_presponsable presuntos_responsables_caso_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_presponsable
    ADD CONSTRAINT presuntos_responsables_caso_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_caso_presponsable presuntos_responsables_caso_id_p_responsable_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_presponsable
    ADD CONSTRAINT presuntos_responsables_caso_id_p_responsable_fkey FOREIGN KEY (id_presponsable) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sivel2_gen_presponsable presuntos_responsables_id_papa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_presponsable
    ADD CONSTRAINT presuntos_responsables_id_papa_fkey FOREIGN KEY (papa_id) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sip_persona_trelacion relacion_personas_id_persona1_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona_trelacion
    ADD CONSTRAINT relacion_personas_id_persona1_fkey FOREIGN KEY (persona1) REFERENCES public.sip_persona(id);


--
-- Name: sip_persona_trelacion relacion_personas_id_persona2_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona_trelacion
    ADD CONSTRAINT relacion_personas_id_persona2_fkey FOREIGN KEY (persona2) REFERENCES public.sip_persona(id);


--
-- Name: sip_persona_trelacion relacion_personas_id_tipo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona_trelacion
    ADD CONSTRAINT relacion_personas_id_tipo_fkey FOREIGN KEY (id_trelacion) REFERENCES public.sip_trelacion(id);


--
-- Name: sip_clase sip_clase_id_municipio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_clase
    ADD CONSTRAINT sip_clase_id_municipio_fkey FOREIGN KEY (id_municipio) REFERENCES public.sip_municipio(id);


--
-- Name: sip_municipio sip_municipio_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_municipio
    ADD CONSTRAINT sip_municipio_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.sip_departamento(id);


--
-- Name: sip_persona sip_persona_id_clase_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona
    ADD CONSTRAINT sip_persona_id_clase_fkey FOREIGN KEY (id_clase) REFERENCES public.sip_clase(id);


--
-- Name: sip_persona sip_persona_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona
    ADD CONSTRAINT sip_persona_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.sip_departamento(id);


--
-- Name: sip_persona sip_persona_id_municipio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_persona
    ADD CONSTRAINT sip_persona_id_municipio_fkey FOREIGN KEY (id_municipio) REFERENCES public.sip_municipio(id);


--
-- Name: sip_ubicacion sip_ubicacion_id_clase_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT sip_ubicacion_id_clase_fkey FOREIGN KEY (id_clase) REFERENCES public.sip_clase(id);


--
-- Name: sip_ubicacion sip_ubicacion_id_departamento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT sip_ubicacion_id_departamento_fkey FOREIGN KEY (id_departamento) REFERENCES public.sip_departamento(id);


--
-- Name: sip_ubicacion sip_ubicacion_id_municipio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT sip_ubicacion_id_municipio_fkey FOREIGN KEY (id_municipio) REFERENCES public.sip_municipio(id);


--
-- Name: sivel2_gen_antecedente_victimacolectiva sivel2_gen_antecedente_victimacolectiv_victimacolectiva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_antecedente_victimacolectiva
    ADD CONSTRAINT sivel2_gen_antecedente_victimacolectiv_victimacolectiva_id_fkey FOREIGN KEY (victimacolectiva_id) REFERENCES public.sivel2_gen_victimacolectiva(id);


--
-- Name: sivel2_gen_caso_fotra sivel2_gen_caso_fotra_anexo_caso_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fotra
    ADD CONSTRAINT sivel2_gen_caso_fotra_anexo_caso_id_fkey FOREIGN KEY (anexo_caso_id) REFERENCES public.sivel2_gen_anexo_caso(id);


--
-- Name: sivel2_gen_caso_fuenteprensa sivel2_gen_caso_fuenteprensa_anexo_caso_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fuenteprensa
    ADD CONSTRAINT sivel2_gen_caso_fuenteprensa_anexo_caso_id_fkey FOREIGN KEY (anexo_caso_id) REFERENCES public.sivel2_gen_anexo_caso(id);


--
-- Name: sivel2_gen_caso_fuenteprensa sivel2_gen_caso_fuenteprensa_fuenteprensa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fuenteprensa
    ADD CONSTRAINT sivel2_gen_caso_fuenteprensa_fuenteprensa_id_fkey FOREIGN KEY (fuenteprensa_id) REFERENCES public.sip_fuenteprensa(id);


--
-- Name: sivel2_gen_caso_fuenteprensa sivel2_gen_caso_fuenteprensa_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_caso_fuenteprensa
    ADD CONSTRAINT sivel2_gen_caso_fuenteprensa_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_categoria sivel2_gen_categoria_supracategoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_categoria
    ADD CONSTRAINT sivel2_gen_categoria_supracategoria_id_fkey FOREIGN KEY (supracategoria_id) REFERENCES public.sivel2_gen_supracategoria(id);


--
-- Name: sivel2_gen_filiacion_victimacolectiva sivel2_gen_filiacion_victimacolectiva_victimacolectiva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_filiacion_victimacolectiva
    ADD CONSTRAINT sivel2_gen_filiacion_victimacolectiva_victimacolectiva_id_fkey FOREIGN KEY (victimacolectiva_id) REFERENCES public.sivel2_gen_victimacolectiva(id);


--
-- Name: sivel2_gen_observador_filtrodepartamento sivel2_gen_observador_filtrodepartamento_d_idx; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_observador_filtrodepartamento
    ADD CONSTRAINT sivel2_gen_observador_filtrodepartamento_d_idx FOREIGN KEY (departamento_id) REFERENCES public.sip_departamento(id);


--
-- Name: sivel2_gen_observador_filtrodepartamento sivel2_gen_observador_filtrodepartamento_u_idx; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_observador_filtrodepartamento
    ADD CONSTRAINT sivel2_gen_observador_filtrodepartamento_u_idx FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: sivel2_gen_organizacion_victimacolectiva sivel2_gen_organizacion_victimacolecti_victimacolectiva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_organizacion_victimacolectiva
    ADD CONSTRAINT sivel2_gen_organizacion_victimacolecti_victimacolectiva_id_fkey FOREIGN KEY (victimacolectiva_id) REFERENCES public.sivel2_gen_victimacolectiva(id);


--
-- Name: sivel2_gen_profesion_victimacolectiva sivel2_gen_profesion_victimacolectiva_victimacolectiva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_profesion_victimacolectiva
    ADD CONSTRAINT sivel2_gen_profesion_victimacolectiva_victimacolectiva_id_fkey FOREIGN KEY (victimacolectiva_id) REFERENCES public.sivel2_gen_victimacolectiva(id);


--
-- Name: sivel2_gen_rangoedad_victimacolectiva sivel2_gen_rangoedad_victimacolectiva_victimacolectiva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_rangoedad_victimacolectiva
    ADD CONSTRAINT sivel2_gen_rangoedad_victimacolectiva_victimacolectiva_id_fkey FOREIGN KEY (victimacolectiva_id) REFERENCES public.sivel2_gen_victimacolectiva(id);


--
-- Name: sivel2_gen_sectorsocial_victimacolectiva sivel2_gen_sectorsocial_victimacolecti_victimacolectiva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_sectorsocial_victimacolectiva
    ADD CONSTRAINT sivel2_gen_sectorsocial_victimacolecti_victimacolectiva_id_fkey FOREIGN KEY (victimacolectiva_id) REFERENCES public.sivel2_gen_victimacolectiva(id);


--
-- Name: sivel2_gen_victimacolectiva_vinculoestado sivel2_gen_victimacolectiva_vinculoest_victimacolectiva_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva_vinculoestado
    ADD CONSTRAINT sivel2_gen_victimacolectiva_vinculoest_victimacolectiva_id_fkey FOREIGN KEY (victimacolectiva_id) REFERENCES public.sivel2_gen_victimacolectiva(id);


--
-- Name: sivel2_gen_supracategoria supracategoria_id_tipo_violencia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_supracategoria
    ADD CONSTRAINT supracategoria_id_tipo_violencia_fkey FOREIGN KEY (id_tviolencia) REFERENCES public.sivel2_gen_tviolencia(id);


--
-- Name: sip_ubicacion ubicacion2_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT ubicacion2_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sip_ubicacion ubicacion2_id_tipo_sitio_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT ubicacion2_id_tipo_sitio_fkey FOREIGN KEY (id_tsitio) REFERENCES public.sip_tsitio(id);


--
-- Name: sip_ubicacion ubicacion_id_pais_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sip_ubicacion
    ADD CONSTRAINT ubicacion_id_pais_fkey FOREIGN KEY (id_pais) REFERENCES public.sip_pais(id);


--
-- Name: sivel2_gen_victimacolectiva victima_colectiva_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva
    ADD CONSTRAINT victima_colectiva_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_victimacolectiva victima_colectiva_id_grupoper_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva
    ADD CONSTRAINT victima_colectiva_id_grupoper_fkey FOREIGN KEY (id_grupoper) REFERENCES public.sip_grupoper(id);


--
-- Name: sivel2_gen_victimacolectiva victima_colectiva_id_organizacion_armada_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victimacolectiva
    ADD CONSTRAINT victima_colectiva_id_organizacion_armada_fkey FOREIGN KEY (organizacionarmada) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sivel2_gen_victima victima_id_caso_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_caso_fkey FOREIGN KEY (id_caso) REFERENCES public.sivel2_gen_caso(id);


--
-- Name: sivel2_gen_victima victima_id_etnia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_etnia_fkey FOREIGN KEY (id_etnia) REFERENCES public.sivel2_gen_etnia(id);


--
-- Name: sivel2_gen_victima victima_id_filiacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_filiacion_fkey FOREIGN KEY (id_filiacion) REFERENCES public.sivel2_gen_filiacion(id);


--
-- Name: sivel2_gen_victima victima_id_iglesia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_iglesia_fkey FOREIGN KEY (id_iglesia) REFERENCES public.sivel2_gen_iglesia(id);


--
-- Name: sivel2_gen_victima victima_id_organizacion_armada_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_organizacion_armada_fkey FOREIGN KEY (organizacionarmada) REFERENCES public.sivel2_gen_presponsable(id);


--
-- Name: sivel2_gen_victima victima_id_organizacion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_organizacion_fkey FOREIGN KEY (id_organizacion) REFERENCES public.sivel2_gen_organizacion(id);


--
-- Name: sivel2_gen_victima victima_id_persona_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_persona_fkey FOREIGN KEY (id_persona) REFERENCES public.sip_persona(id);


--
-- Name: sivel2_gen_victima victima_id_profesion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_profesion_fkey FOREIGN KEY (id_profesion) REFERENCES public.sivel2_gen_profesion(id);


--
-- Name: sivel2_gen_victima victima_id_rango_edad_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_rango_edad_fkey FOREIGN KEY (id_rangoedad) REFERENCES public.sivel2_gen_rangoedad(id);


--
-- Name: sivel2_gen_victima victima_id_sector_social_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_sector_social_fkey FOREIGN KEY (id_sectorsocial) REFERENCES public.sivel2_gen_sectorsocial(id);


--
-- Name: sivel2_gen_victima victima_id_vinculo_estado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sivel2_gen_victima
    ADD CONSTRAINT victima_id_vinculo_estado_fkey FOREIGN KEY (id_vinculoestado) REFERENCES public.sivel2_gen_vinculoestado(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20131128151014'),
('20131204135932'),
('20131204140000'),
('20131204143718'),
('20131204183530'),
('20131206081531'),
('20131210221541'),
('20131220103409'),
('20131223175141'),
('20140117212555'),
('20140129151136'),
('20140207102709'),
('20140207102739'),
('20140211162355'),
('20140211164659'),
('20140211172443'),
('20140313012209'),
('20140514142421'),
('20140518120059'),
('20140527110223'),
('20140528043115'),
('20140804202100'),
('20140804202101'),
('20140804202958'),
('20140815111351'),
('20140827142659'),
('20140901105741'),
('20140901106000'),
('20140909165233'),
('20140918115412'),
('20140922102737'),
('20140922110956'),
('20141002140242'),
('20141111102451'),
('20141111203313'),
('20150313153722'),
('20150317084737'),
('20150413000000'),
('20150413160156'),
('20150413160157'),
('20150413160158'),
('20150413160159'),
('20150416074423'),
('20150416090140'),
('20150503120915'),
('20150505084914'),
('20150510125926'),
('20150521181918'),
('20150528100944'),
('20150602094513'),
('20150602095241'),
('20150602104342'),
('20150609094809'),
('20150609094820'),
('20150616095023'),
('20150616100351'),
('20150616100551'),
('20150707164448'),
('20150710114451'),
('20150716171420'),
('20150716192356'),
('20150717101243'),
('20150724003736'),
('20150803082520'),
('20150809032138'),
('20150826000000'),
('20151020203421'),
('20151124110943'),
('20151127102425'),
('20151130101417'),
('20160316093659'),
('20160316094627'),
('20160316100620'),
('20160316100621'),
('20160316100622'),
('20160316100623'),
('20160316100624'),
('20160316100625'),
('20160316100626'),
('20160519195544'),
('20160719195853'),
('20160719214520'),
('20160724160049'),
('20160724164110'),
('20160725123242'),
('20160725131347'),
('20161009111443'),
('20161010152631'),
('20161026110802'),
('20161027233011'),
('20161103080156'),
('20161103081041'),
('20161103083352'),
('20161108102349'),
('20170405104322'),
('20170406213334'),
('20170413185012'),
('20170414035328'),
('20170503145808'),
('20170526084502'),
('20170526100040'),
('20170526124219'),
('20170526131129'),
('20170529020218'),
('20170529154413'),
('20170609131212'),
('20170928100402'),
('20171019133203'),
('20180126035129'),
('20180126055129'),
('20180225152848'),
('20180320230847'),
('20180427194732'),
('20180509111948'),
('20180717134314'),
('20180717135811'),
('20180718094829'),
('20180719015902'),
('20180720140443'),
('20180720171842'),
('20180724135332'),
('20180724202353'),
('20180726213123'),
('20180726234755'),
('20180801105304'),
('20180810221619'),
('20180905031342'),
('20180905031617'),
('20180910132139'),
('20180912114413'),
('20180914153010'),
('20180917072914'),
('20180920031351'),
('20180921120954'),
('20181011104537'),
('20181012110629'),
('20181017094456'),
('20181018003945'),
('20181130112320'),
('20181213103204'),
('20181218165548'),
('20181218165559'),
('20181218215222'),
('20181219085236'),
('20181227093834'),
('20181227094559'),
('20181227095037'),
('20181227100523'),
('20181227114431'),
('20181227210510'),
('20190109125417'),
('20190110191802'),
('20190128032125'),
('20190208103518'),
('20190308195346'),
('20190322102311'),
('20190326150948'),
('20190331111015'),
('20190401175521'),
('20190406141156'),
('20190406164301'),
('20190418011743'),
('20190418014012'),
('20190418123920'),
('20190426125052'),
('20190430112229'),
('20190605143420'),
('20190612111043'),
('20190618135559'),
('20190625112649'),
('20190625140232'),
('20190703044126'),
('20190715083916'),
('20190715182611'),
('20190726203302'),
('20190804223012'),
('20190818013251'),
('20190924013712'),
('20190924112646'),
('20190926104116'),
('20190926104551'),
('20190926133640'),
('20190926143845'),
('20191012042159'),
('20191016100031'),
('20191021021621'),
('20191205200007'),
('20191205202150'),
('20191205204511'),
('20191219011910'),
('20191231102721'),
('20200106174710'),
('20200221181049'),
('20200224134339'),
('20200228235200'),
('20200319183515'),
('20200320152017'),
('20200324164130'),
('20200422103916'),
('20200423092828'),
('20200427091939'),
('20200428155536'),
('20200430101709'),
('20200622193241'),
('20200720005020'),
('20200720013144'),
('20200722210144'),
('20200723133542'),
('20200727021707'),
('20200907165157'),
('20200907174303'),
('20200916022934'),
('20200919003430'),
('20200921123831'),
('20201009004421'),
('20201119125643'),
('20201130020715'),
('20201201015501'),
('20201214215209'),
('20201231194433'),
('20210206191033'),
('20210226155035'),
('20210316082124'),
('20210401194637'),
('20210401210102'),
('20210414201956'),
('20210428143811'),
('20210430160739'),
('20210531223906'),
('20210601023450'),
('20210601023557'),
('20210614120835'),
('20210616003251'),
('20210619191706'),
('20210727111355'),
('20210728214424'),
('20210730120340'),
('20210823162357'),
('20210915184354'),
('20210915184355'),
('20210915184356'),
('20210915184357'),
('20210915184358'),
('20210915184359'),
('20210915184360'),
('20210915184361'),
('20210915184362'),
('20210915184363'),
('20210915184364'),
('20210915184365'),
('20210915184366'),
('20210915184367'),
('20210915184368'),
('20210915184369'),
('20210915184370'),
('20210915184371'),
('20210915184372'),
('20210915184373'),
('20210915184374'),
('20210915184375'),
('20210915184376'),
('20210915184377'),
('20210915184378'),
('20210915184379'),
('20210915184380'),
('20210915184381'),
('20210915184382'),
('20210915184383'),
('20210915184384'),
('20210915184385'),
('20210915184386'),
('20210915184387'),
('20210915184388'),
('20210915184389'),
('20210915184390'),
('20210915184621'),
('20210915204937'),
('20210915220932');


