PGDMP     6                    }            figgy_production "   15.12 (Ubuntu 15.12-1.pgdg22.04+1) "   15.12 (Ubuntu 15.12-1.pgdg22.04+1) �    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                      false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                      false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                      false            �           1262    2772940    figgy_production    DATABASE     |   CREATE DATABASE figgy_production WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';
     DROP DATABASE figgy_production;
                figgy_production    false                        3079    2772941 	   uuid-ossp 	   EXTENSION     ?   CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
    DROP EXTENSION "uuid-ossp";
                   false            �           0    0    EXTENSION "uuid-ossp"    COMMENT     W   COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';
                        false    2                       1255    2772952    get_ids(jsonb, text)    FUNCTION     �   CREATE FUNCTION public.get_ids(jsonb, text) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $_$
      select jsonb_agg(x) from
         (select jsonb_array_elements($1->$2)->>'id') as f(x);
      $_$;
 +   DROP FUNCTION public.get_ids(jsonb, text);
       public          figgy_staging    false                       1255    2772953    get_ids_array(jsonb, text)    FUNCTION     �   CREATE FUNCTION public.get_ids_array(jsonb, text) RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $_$
      select array_agg(x) from
         (select jsonb_array_elements($1->$2)->>'id') as f(x);
      $_$;
 1   DROP FUNCTION public.get_ids_array(jsonb, text);
       public          figgy_staging    false            �            1259    2772954    active_storage_attachments    TABLE       CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
);
 .   DROP TABLE public.active_storage_attachments;
       public         heap    figgy_staging    false            �           0    0     TABLE active_storage_attachments    ACL     !  GRANT SELECT ON TABLE public.active_storage_attachments TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.active_storage_attachments TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.active_storage_attachments TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    215            �            1259    2772959 !   active_storage_attachments_id_seq    SEQUENCE     �   CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE public.active_storage_attachments_id_seq;
       public          figgy_staging    false    215            �           0    0 !   active_storage_attachments_id_seq    SEQUENCE OWNED BY     g   ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;
          public          figgy_staging    false    216            �            1259    2772960    active_storage_blobs    TABLE     s  CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    byte_size bigint NOT NULL,
    checksum character varying NOT NULL,
    created_at timestamp without time zone NOT NULL,
    service_name character varying NOT NULL
);
 (   DROP TABLE public.active_storage_blobs;
       public         heap    figgy_staging    false            �           0    0    TABLE active_storage_blobs    ACL       GRANT SELECT ON TABLE public.active_storage_blobs TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.active_storage_blobs TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.active_storage_blobs TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    217            �            1259    2772965    active_storage_blobs_id_seq    SEQUENCE     �   CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.active_storage_blobs_id_seq;
       public          figgy_staging    false    217            �           0    0    active_storage_blobs_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;
          public          figgy_staging    false    218            �            1259    2772966    active_storage_variant_records    TABLE     �   CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);
 2   DROP TABLE public.active_storage_variant_records;
       public         heap    figgy_staging    false            �           0    0 $   TABLE active_storage_variant_records    ACL     -  GRANT SELECT ON TABLE public.active_storage_variant_records TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.active_storage_variant_records TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.active_storage_variant_records TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    219            �            1259    2772971 %   active_storage_variant_records_id_seq    SEQUENCE     �   CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.active_storage_variant_records_id_seq;
       public          figgy_staging    false    219            �           0    0 %   active_storage_variant_records_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;
          public          figgy_staging    false    220            �            1259    2772972    ar_internal_metadata    TABLE     �   CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);
 (   DROP TABLE public.ar_internal_metadata;
       public         heap    figgy_staging    false            �           0    0    TABLE ar_internal_metadata    ACL       GRANT SELECT ON TABLE public.ar_internal_metadata TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.ar_internal_metadata TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.ar_internal_metadata TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    221            �            1259    2772977    auth_tokens    TABLE     "  CREATE TABLE public.auth_tokens (
    id bigint NOT NULL,
    label character varying,
    "group" character varying,
    token character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    resource_id character varying
);
    DROP TABLE public.auth_tokens;
       public         heap    figgy_staging    false            �           0    0    TABLE auth_tokens    ACL     �   GRANT SELECT ON TABLE public.auth_tokens TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.auth_tokens TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.auth_tokens TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    222            �            1259    2772982    auth_tokens_id_seq    SEQUENCE     {   CREATE SEQUENCE public.auth_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.auth_tokens_id_seq;
       public          figgy_staging    false    222            �           0    0    auth_tokens_id_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.auth_tokens_id_seq OWNED BY public.auth_tokens.id;
          public          figgy_staging    false    223            �            1259    2772983 	   bookmarks    TABLE     =  CREATE TABLE public.bookmarks (
    id integer NOT NULL,
    user_id integer NOT NULL,
    user_type character varying,
    document_id character varying,
    document_type character varying,
    title bytea,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);
    DROP TABLE public.bookmarks;
       public         heap    figgy_staging    false            �           0    0    TABLE bookmarks    ACL     �   GRANT SELECT ON TABLE public.bookmarks TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.bookmarks TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.bookmarks TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    224            �            1259    2772988    bookmarks_id_seq    SEQUENCE     y   CREATE SEQUENCE public.bookmarks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.bookmarks_id_seq;
       public          figgy_staging    false    224            �           0    0    bookmarks_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.bookmarks_id_seq OWNED BY public.bookmarks.id;
          public          figgy_staging    false    225            �            1259    2772989 &   browse_everything_authorization_models    TABLE     �   CREATE TABLE public.browse_everything_authorization_models (
    id bigint NOT NULL,
    uuid character varying,
    "authorization" text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);
 :   DROP TABLE public.browse_everything_authorization_models;
       public         heap    figgy_staging    false            �           0    0 ,   TABLE browse_everything_authorization_models    ACL     E  GRANT SELECT ON TABLE public.browse_everything_authorization_models TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.browse_everything_authorization_models TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.browse_everything_authorization_models TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    226            �            1259    2772994 -   browse_everything_authorization_models_id_seq    SEQUENCE     �   CREATE SEQUENCE public.browse_everything_authorization_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.browse_everything_authorization_models_id_seq;
       public          figgy_staging    false    226            �           0    0 -   browse_everything_authorization_models_id_seq    SEQUENCE OWNED BY        ALTER SEQUENCE public.browse_everything_authorization_models_id_seq OWNED BY public.browse_everything_authorization_models.id;
          public          figgy_staging    false    227            �            1259    2772995     browse_everything_session_models    TABLE     �   CREATE TABLE public.browse_everything_session_models (
    id bigint NOT NULL,
    uuid character varying,
    session text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);
 4   DROP TABLE public.browse_everything_session_models;
       public         heap    figgy_staging    false            �           0    0 &   TABLE browse_everything_session_models    ACL     3  GRANT SELECT ON TABLE public.browse_everything_session_models TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.browse_everything_session_models TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.browse_everything_session_models TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    228            �            1259    2773000 '   browse_everything_session_models_id_seq    SEQUENCE     �   CREATE SEQUENCE public.browse_everything_session_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 >   DROP SEQUENCE public.browse_everything_session_models_id_seq;
       public          figgy_staging    false    228            �           0    0 '   browse_everything_session_models_id_seq    SEQUENCE OWNED BY     s   ALTER SEQUENCE public.browse_everything_session_models_id_seq OWNED BY public.browse_everything_session_models.id;
          public          figgy_staging    false    229            �            1259    2773001    browse_everything_upload_files    TABLE     d  CREATE TABLE public.browse_everything_upload_files (
    id bigint NOT NULL,
    container_id character varying,
    name character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    file_path character varying,
    file_name character varying,
    file_content_type character varying
);
 2   DROP TABLE public.browse_everything_upload_files;
       public         heap    figgy_staging    false            �           0    0 $   TABLE browse_everything_upload_files    ACL     -  GRANT SELECT ON TABLE public.browse_everything_upload_files TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.browse_everything_upload_files TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.browse_everything_upload_files TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    230            �            1259    2773006 %   browse_everything_upload_files_id_seq    SEQUENCE     �   CREATE SEQUENCE public.browse_everything_upload_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.browse_everything_upload_files_id_seq;
       public          figgy_staging    false    230            �           0    0 %   browse_everything_upload_files_id_seq    SEQUENCE OWNED BY     o   ALTER SEQUENCE public.browse_everything_upload_files_id_seq OWNED BY public.browse_everything_upload_files.id;
          public          figgy_staging    false    231            �            1259    2773007    browse_everything_upload_models    TABLE     �   CREATE TABLE public.browse_everything_upload_models (
    id bigint NOT NULL,
    uuid character varying,
    upload text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);
 3   DROP TABLE public.browse_everything_upload_models;
       public         heap    figgy_staging    false            �           0    0 %   TABLE browse_everything_upload_models    ACL     0  GRANT SELECT ON TABLE public.browse_everything_upload_models TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.browse_everything_upload_models TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.browse_everything_upload_models TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    232            �            1259    2773012 &   browse_everything_upload_models_id_seq    SEQUENCE     �   CREATE SEQUENCE public.browse_everything_upload_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.browse_everything_upload_models_id_seq;
       public          figgy_staging    false    232            �           0    0 &   browse_everything_upload_models_id_seq    SEQUENCE OWNED BY     q   ALTER SEQUENCE public.browse_everything_upload_models_id_seq OWNED BY public.browse_everything_upload_models.id;
          public          figgy_staging    false    233            �            1259    2773013    delayed_jobs    TABLE     �  CREATE TABLE public.delayed_jobs (
    id integer NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    handler text NOT NULL,
    last_error text,
    run_at timestamp without time zone,
    locked_at timestamp without time zone,
    failed_at timestamp without time zone,
    locked_by character varying,
    queue character varying,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);
     DROP TABLE public.delayed_jobs;
       public         heap    figgy_staging    false            �           0    0    TABLE delayed_jobs    ACL     �   GRANT SELECT ON TABLE public.delayed_jobs TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.delayed_jobs TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.delayed_jobs TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    234            �            1259    2773020    delayed_jobs_id_seq    SEQUENCE     |   CREATE SEQUENCE public.delayed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.delayed_jobs_id_seq;
       public          figgy_staging    false    234            �           0    0    delayed_jobs_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.delayed_jobs_id_seq OWNED BY public.delayed_jobs.id;
          public          figgy_staging    false    235            �            1259    2773021    ocr_requests    TABLE       CREATE TABLE public.ocr_requests (
    id bigint NOT NULL,
    filename character varying,
    state character varying,
    note text,
    user_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);
     DROP TABLE public.ocr_requests;
       public         heap    figgy_staging    false            �           0    0    TABLE ocr_requests    ACL     �   GRANT SELECT ON TABLE public.ocr_requests TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.ocr_requests TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.ocr_requests TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    236            �            1259    2773026    ocr_requests_id_seq    SEQUENCE     |   CREATE SEQUENCE public.ocr_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.ocr_requests_id_seq;
       public          figgy_staging    false    236            �           0    0    ocr_requests_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.ocr_requests_id_seq OWNED BY public.ocr_requests.id;
          public          figgy_staging    false    237            �            1259    2773027    orm_resources    TABLE     <  CREATE TABLE public.orm_resources (
    id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    internal_resource character varying,
    lock_version integer
);
 !   DROP TABLE public.orm_resources;
       public         heap    figgy_staging    false    2            �           0    0    TABLE orm_resources    ACL     �   GRANT SELECT ON TABLE public.orm_resources TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.orm_resources TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.orm_resources TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    238            �            1259    2773034    roles    TABLE     S   CREATE TABLE public.roles (
    id integer NOT NULL,
    name character varying
);
    DROP TABLE public.roles;
       public         heap    figgy_staging    false            �           0    0    TABLE roles    ACL     �   GRANT SELECT ON TABLE public.roles TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.roles TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.roles TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    239            �            1259    2773039    roles_id_seq    SEQUENCE     u   CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.roles_id_seq;
       public          figgy_staging    false    239            �           0    0    roles_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;
          public          figgy_staging    false    240            �            1259    2773040    roles_users    TABLE     N   CREATE TABLE public.roles_users (
    role_id integer,
    user_id integer
);
    DROP TABLE public.roles_users;
       public         heap    figgy_staging    false            �           0    0    TABLE roles_users    ACL     �   GRANT SELECT ON TABLE public.roles_users TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.roles_users TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.roles_users TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    241            �            1259    2773043    schema_migrations    TABLE     R   CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);
 %   DROP TABLE public.schema_migrations;
       public         heap    figgy_staging    false            �           0    0    TABLE schema_migrations    ACL       GRANT SELECT ON TABLE public.schema_migrations TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.schema_migrations TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.schema_migrations TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    242            �            1259    2773048    searches    TABLE     �   CREATE TABLE public.searches (
    id integer NOT NULL,
    query_params bytea,
    user_id integer,
    user_type character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);
    DROP TABLE public.searches;
       public         heap    figgy_staging    false            �           0    0    TABLE searches    ACL     �   GRANT SELECT ON TABLE public.searches TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.searches TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.searches TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    243            �            1259    2773053    searches_id_seq    SEQUENCE     x   CREATE SEQUENCE public.searches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.searches_id_seq;
       public          figgy_staging    false    243            �           0    0    searches_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE public.searches_id_seq OWNED BY public.searches.id;
          public          figgy_staging    false    244            �            1259    2773054    users    TABLE     �  CREATE TABLE public.users (
    id bigint NOT NULL,
    email character varying DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip inet,
    last_sign_in_ip inet,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    guest boolean DEFAULT false,
    provider character varying,
    uid character varying
);
    DROP TABLE public.users;
       public         heap    figgy_staging    false            �           0    0    TABLE users    ACL     �   GRANT SELECT ON TABLE public.users TO figgy_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.users TO figgy_production_readonly WITH GRANT OPTION;
GRANT SELECT ON TABLE public.users TO dpulc_staging WITH GRANT OPTION;
          public          figgy_staging    false    245            �            1259    2773063    users_id_seq    SEQUENCE     u   CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.users_id_seq;
       public          figgy_staging    false    245            �           0    0    users_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;
          public          figgy_staging    false    246            �           2604    2773064    active_storage_attachments id    DEFAULT     �   ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);
 L   ALTER TABLE public.active_storage_attachments ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    216    215            �           2604    2773065    active_storage_blobs id    DEFAULT     �   ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);
 F   ALTER TABLE public.active_storage_blobs ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    218    217            �           2604    2773066 !   active_storage_variant_records id    DEFAULT     �   ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);
 P   ALTER TABLE public.active_storage_variant_records ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    220    219            �           2604    2773067    auth_tokens id    DEFAULT     p   ALTER TABLE ONLY public.auth_tokens ALTER COLUMN id SET DEFAULT nextval('public.auth_tokens_id_seq'::regclass);
 =   ALTER TABLE public.auth_tokens ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    223    222            �           2604    2773068    bookmarks id    DEFAULT     l   ALTER TABLE ONLY public.bookmarks ALTER COLUMN id SET DEFAULT nextval('public.bookmarks_id_seq'::regclass);
 ;   ALTER TABLE public.bookmarks ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    225    224            �           2604    2773069 )   browse_everything_authorization_models id    DEFAULT     �   ALTER TABLE ONLY public.browse_everything_authorization_models ALTER COLUMN id SET DEFAULT nextval('public.browse_everything_authorization_models_id_seq'::regclass);
 X   ALTER TABLE public.browse_everything_authorization_models ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    227    226            �           2604    2773070 #   browse_everything_session_models id    DEFAULT     �   ALTER TABLE ONLY public.browse_everything_session_models ALTER COLUMN id SET DEFAULT nextval('public.browse_everything_session_models_id_seq'::regclass);
 R   ALTER TABLE public.browse_everything_session_models ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    229    228            �           2604    2773071 !   browse_everything_upload_files id    DEFAULT     �   ALTER TABLE ONLY public.browse_everything_upload_files ALTER COLUMN id SET DEFAULT nextval('public.browse_everything_upload_files_id_seq'::regclass);
 P   ALTER TABLE public.browse_everything_upload_files ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    231    230            �           2604    2773072 "   browse_everything_upload_models id    DEFAULT     �   ALTER TABLE ONLY public.browse_everything_upload_models ALTER COLUMN id SET DEFAULT nextval('public.browse_everything_upload_models_id_seq'::regclass);
 Q   ALTER TABLE public.browse_everything_upload_models ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    233    232            �           2604    2773073    delayed_jobs id    DEFAULT     r   ALTER TABLE ONLY public.delayed_jobs ALTER COLUMN id SET DEFAULT nextval('public.delayed_jobs_id_seq'::regclass);
 >   ALTER TABLE public.delayed_jobs ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    235    234            �           2604    2773074    ocr_requests id    DEFAULT     r   ALTER TABLE ONLY public.ocr_requests ALTER COLUMN id SET DEFAULT nextval('public.ocr_requests_id_seq'::regclass);
 >   ALTER TABLE public.ocr_requests ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    237    236            �           2604    2773075    roles id    DEFAULT     d   ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);
 7   ALTER TABLE public.roles ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    240    239            �           2604    2773076    searches id    DEFAULT     j   ALTER TABLE ONLY public.searches ALTER COLUMN id SET DEFAULT nextval('public.searches_id_seq'::regclass);
 :   ALTER TABLE public.searches ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    244    243            �           2604    2773077    users id    DEFAULT     d   ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);
 7   ALTER TABLE public.users ALTER COLUMN id DROP DEFAULT;
       public          figgy_staging    false    246    245            �           2606    4788827 :   active_storage_attachments active_storage_attachments_pkey 
   CONSTRAINT     x   ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);
 d   ALTER TABLE ONLY public.active_storage_attachments DROP CONSTRAINT active_storage_attachments_pkey;
       public            figgy_staging    false    215            �           2606    4788829 .   active_storage_blobs active_storage_blobs_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.active_storage_blobs DROP CONSTRAINT active_storage_blobs_pkey;
       public            figgy_staging    false    217            �           2606    4788831 B   active_storage_variant_records active_storage_variant_records_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.active_storage_variant_records DROP CONSTRAINT active_storage_variant_records_pkey;
       public            figgy_staging    false    219            �           2606    4788833 .   ar_internal_metadata ar_internal_metadata_pkey 
   CONSTRAINT     m   ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);
 X   ALTER TABLE ONLY public.ar_internal_metadata DROP CONSTRAINT ar_internal_metadata_pkey;
       public            figgy_staging    false    221            �           2606    4788835    auth_tokens auth_tokens_pkey 
   CONSTRAINT     Z   ALTER TABLE ONLY public.auth_tokens
    ADD CONSTRAINT auth_tokens_pkey PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.auth_tokens DROP CONSTRAINT auth_tokens_pkey;
       public            figgy_staging    false    222            �           2606    4788837    bookmarks bookmarks_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.bookmarks DROP CONSTRAINT bookmarks_pkey;
       public            figgy_staging    false    224            �           2606    4788839 R   browse_everything_authorization_models browse_everything_authorization_models_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.browse_everything_authorization_models
    ADD CONSTRAINT browse_everything_authorization_models_pkey PRIMARY KEY (id);
 |   ALTER TABLE ONLY public.browse_everything_authorization_models DROP CONSTRAINT browse_everything_authorization_models_pkey;
       public            figgy_staging    false    226            �           2606    4788841 F   browse_everything_session_models browse_everything_session_models_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.browse_everything_session_models
    ADD CONSTRAINT browse_everything_session_models_pkey PRIMARY KEY (id);
 p   ALTER TABLE ONLY public.browse_everything_session_models DROP CONSTRAINT browse_everything_session_models_pkey;
       public            figgy_staging    false    228            �           2606    4788843 B   browse_everything_upload_files browse_everything_upload_files_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.browse_everything_upload_files
    ADD CONSTRAINT browse_everything_upload_files_pkey PRIMARY KEY (id);
 l   ALTER TABLE ONLY public.browse_everything_upload_files DROP CONSTRAINT browse_everything_upload_files_pkey;
       public            figgy_staging    false    230            �           2606    4788845 D   browse_everything_upload_models browse_everything_upload_models_pkey 
   CONSTRAINT     �   ALTER TABLE ONLY public.browse_everything_upload_models
    ADD CONSTRAINT browse_everything_upload_models_pkey PRIMARY KEY (id);
 n   ALTER TABLE ONLY public.browse_everything_upload_models DROP CONSTRAINT browse_everything_upload_models_pkey;
       public            figgy_staging    false    232            �           2606    4788847    delayed_jobs delayed_jobs_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.delayed_jobs
    ADD CONSTRAINT delayed_jobs_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.delayed_jobs DROP CONSTRAINT delayed_jobs_pkey;
       public            figgy_staging    false    234            �           2606    4788849    ocr_requests ocr_requests_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.ocr_requests
    ADD CONSTRAINT ocr_requests_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.ocr_requests DROP CONSTRAINT ocr_requests_pkey;
       public            figgy_staging    false    236                       2606    4788851     orm_resources orm_resources_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.orm_resources
    ADD CONSTRAINT orm_resources_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.orm_resources DROP CONSTRAINT orm_resources_pkey;
       public            figgy_staging    false    238                       2606    4788853    roles roles_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.roles DROP CONSTRAINT roles_pkey;
       public            figgy_staging    false    239                        2606    4788855 (   schema_migrations schema_migrations_pkey 
   CONSTRAINT     k   ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);
 R   ALTER TABLE ONLY public.schema_migrations DROP CONSTRAINT schema_migrations_pkey;
       public            figgy_staging    false    242            #           2606    4788857    searches searches_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.searches
    ADD CONSTRAINT searches_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.searches DROP CONSTRAINT searches_pkey;
       public            figgy_staging    false    243            )           2606    4788859    users users_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.users DROP CONSTRAINT users_pkey;
       public            figgy_staging    false    245                        1259    8246942    current_events_idx    INDEX     �   CREATE INDEX current_events_idx ON public.orm_resources USING btree ((((metadata -> 'current'::text) ->> 0))) WHERE ((internal_resource)::text = 'Event'::text);
 &   DROP INDEX public.current_events_idx;
       public            figgy_staging    false    238    238    238            �           1259    8246939    delayed_jobs_priority    INDEX     Z   CREATE INDEX delayed_jobs_priority ON public.delayed_jobs USING btree (priority, run_at);
 )   DROP INDEX public.delayed_jobs_priority;
       public            figgy_staging    false    234    234                       1259    8246943    flat_member_ids_array_idx    INDEX        CREATE INDEX flat_member_ids_array_idx ON public.orm_resources USING gin (public.get_ids_array(metadata, 'member_ids'::text));
 -   DROP INDEX public.flat_member_ids_array_idx;
       public            figgy_staging    false    238    238    258                       1259    8246944    flat_member_ids_idx    INDEX     s   CREATE INDEX flat_member_ids_idx ON public.orm_resources USING gin (public.get_ids(metadata, 'member_ids'::text));
 '   DROP INDEX public.flat_member_ids_idx;
       public            figgy_staging    false    238    238    257                       1259    8246945    flat_proxied_file_id_idx    INDEX     �   CREATE INDEX flat_proxied_file_id_idx ON public.orm_resources USING gin (public.get_ids_array(metadata, 'proxied_file_id'::text));
 ,   DROP INDEX public.flat_proxied_file_id_idx;
       public            figgy_staging    false    238    258    238                       1259    8246946    idx_cached_parent_id    INDEX     z   CREATE INDEX idx_cached_parent_id ON public.orm_resources USING btree ((((metadata -> 'cached_parent_id'::text) ->> 0)));
 (   DROP INDEX public.idx_cached_parent_id;
       public            figgy_staging    false    238    238            �           1259    8246904 +   index_active_storage_attachments_on_blob_id    INDEX     u   CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);
 ?   DROP INDEX public.index_active_storage_attachments_on_blob_id;
       public            figgy_staging    false    215            �           1259    8246905 +   index_active_storage_attachments_uniqueness    INDEX     �   CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);
 ?   DROP INDEX public.index_active_storage_attachments_uniqueness;
       public            figgy_staging    false    215    215    215    215            �           1259    8246915 !   index_active_storage_blobs_on_key    INDEX     h   CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);
 5   DROP INDEX public.index_active_storage_blobs_on_key;
       public            figgy_staging    false    217            �           1259    8246928 /   index_active_storage_variant_records_uniqueness    INDEX     �   CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);
 C   DROP INDEX public.index_active_storage_variant_records_uniqueness;
       public            figgy_staging    false    219    219            �           1259    8246920    index_bookmarks_on_document_id    INDEX     [   CREATE INDEX index_bookmarks_on_document_id ON public.bookmarks USING btree (document_id);
 2   DROP INDEX public.index_bookmarks_on_document_id;
       public            figgy_staging    false    224            �           1259    8246921    index_bookmarks_on_user_id    INDEX     S   CREATE INDEX index_bookmarks_on_user_id ON public.bookmarks USING btree (user_id);
 .   DROP INDEX public.index_bookmarks_on_user_id;
       public            figgy_staging    false    224            �           1259    8246908    index_ocr_requests_on_user_id    INDEX     Y   CREATE INDEX index_ocr_requests_on_user_id ON public.ocr_requests USING btree (user_id);
 1   DROP INDEX public.index_ocr_requests_on_user_id;
       public            figgy_staging    false    236                       1259    8246947 $   index_orm_resources_on_current_event    INDEX       CREATE UNIQUE INDEX index_orm_resources_on_current_event ON public.orm_resources USING btree (((metadata ->> 'resource_id'::text)), ((metadata ->> 'child_id'::text))) WHERE (((internal_resource)::text = 'Event'::text) AND (metadata @> '{"current": [true]}'::jsonb));
 8   DROP INDEX public.index_orm_resources_on_current_event;
       public            figgy_staging    false    238    238    238    238                       1259    8624126 -   index_orm_resources_on_current_metadata_event    INDEX     +  CREATE UNIQUE INDEX index_orm_resources_on_current_metadata_event ON public.orm_resources USING btree (((metadata ->> 'resource_id'::text)), ((metadata ->> 'type'::text))) WHERE (((internal_resource)::text = 'Event'::text) AND (metadata @> '{"type": ["metadata_node"], "current": [true]}'::jsonb));
 A   DROP INDEX public.index_orm_resources_on_current_metadata_event;
       public            figgy_staging    false    238    238    238    238                       1259    8246948 !   index_orm_resources_on_id_varchar    INDEX     p   CREATE INDEX index_orm_resources_on_id_varchar ON public.orm_resources USING btree (((id)::character varying));
 5   DROP INDEX public.index_orm_resources_on_id_varchar;
       public            figgy_staging    false    238    238                       1259    8246949 (   index_orm_resources_on_internal_resource    INDEX     o   CREATE INDEX index_orm_resources_on_internal_resource ON public.orm_resources USING btree (internal_resource);
 <   DROP INDEX public.index_orm_resources_on_internal_resource;
       public            figgy_staging    false    238            	           1259    8246950    index_orm_resources_on_metadata    INDEX     [   CREATE INDEX index_orm_resources_on_metadata ON public.orm_resources USING gin (metadata);
 3   DROP INDEX public.index_orm_resources_on_metadata;
       public            figgy_staging    false    238            
           1259    8246951 .   index_orm_resources_on_metadata_jsonb_path_ops    INDEX     y   CREATE INDEX index_orm_resources_on_metadata_jsonb_path_ops ON public.orm_resources USING gin (metadata jsonb_path_ops);
 B   DROP INDEX public.index_orm_resources_on_metadata_jsonb_path_ops;
       public            figgy_staging    false    238                       1259    8246952 3   index_orm_resources_on_metadata_preserved_object_id    INDEX     �   CREATE UNIQUE INDEX index_orm_resources_on_metadata_preserved_object_id ON public.orm_resources USING btree (((metadata ->> 'preserved_object_id'::text))) WHERE ((internal_resource)::text = 'PreservationObject'::text);
 G   DROP INDEX public.index_orm_resources_on_metadata_preserved_object_id;
       public            figgy_staging    false    238    238    238                       1259    8246953 !   index_orm_resources_on_updated_at    INDEX     a   CREATE INDEX index_orm_resources_on_updated_at ON public.orm_resources USING btree (updated_at);
 5   DROP INDEX public.index_orm_resources_on_updated_at;
       public            figgy_staging    false    238                       1259    8246987 (   index_roles_users_on_role_id_and_user_id    INDEX     l   CREATE INDEX index_roles_users_on_role_id_and_user_id ON public.roles_users USING btree (role_id, user_id);
 <   DROP INDEX public.index_roles_users_on_role_id_and_user_id;
       public            figgy_staging    false    241    241                       1259    8246988 (   index_roles_users_on_user_id_and_role_id    INDEX     l   CREATE INDEX index_roles_users_on_user_id_and_role_id ON public.roles_users USING btree (user_id, role_id);
 <   DROP INDEX public.index_roles_users_on_user_id_and_role_id;
       public            figgy_staging    false    241    241            !           1259    8246990    index_searches_on_user_id    INDEX     Q   CREATE INDEX index_searches_on_user_id ON public.searches USING btree (user_id);
 -   DROP INDEX public.index_searches_on_user_id;
       public            figgy_staging    false    243            $           1259    8246993    index_users_on_email    INDEX     G   CREATE INDEX index_users_on_email ON public.users USING btree (email);
 (   DROP INDEX public.index_users_on_email;
       public            figgy_staging    false    245            %           1259    8246994    index_users_on_provider    INDEX     M   CREATE INDEX index_users_on_provider ON public.users USING btree (provider);
 +   DROP INDEX public.index_users_on_provider;
       public            figgy_staging    false    245            &           1259    8246995 #   index_users_on_reset_password_token    INDEX     l   CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);
 7   DROP INDEX public.index_users_on_reset_password_token;
       public            figgy_staging    false    245            '           1259    8246996    index_users_on_uid    INDEX     C   CREATE INDEX index_users_on_uid ON public.users USING btree (uid);
 &   DROP INDEX public.index_users_on_uid;
       public            figgy_staging    false    245                       1259    10773930    mms_id_substring_idx    INDEX     {  CREATE INDEX mms_id_substring_idx ON public.orm_resources USING btree ("substring"(((metadata -> 'source_metadata_identifier'::text) ->> 0), 1, 2)) WHERE ((internal_resource)::text <> ALL ((ARRAY['FileSet'::character varying, 'PreservationObject'::character varying, 'DeletionMarker'::character varying, 'Event'::character varying, 'EphemeraTerm'::character varying])::text[]));
 (   DROP INDEX public.mms_id_substring_idx;
       public            figgy_staging    false    238    238    238                       1259    8246954    orm_resources_expr_idx    INDEX     p   CREATE INDEX orm_resources_expr_idx ON public.orm_resources USING btree (((metadata -> 'thumbnail_id'::text)));
 *   DROP INDEX public.orm_resources_expr_idx;
       public            figgy_staging    false    238    238                       1259    8246955 (   orm_resources_first_accession_number_idx    INDEX     �   CREATE INDEX orm_resources_first_accession_number_idx ON public.orm_resources USING btree ((((metadata -> 'accession_number'::text) -> 0)));
 <   DROP INDEX public.orm_resources_first_accession_number_idx;
       public            figgy_staging    false    238    238                       1259    8246956 #   orm_resources_first_coin_number_idx    INDEX     �   CREATE INDEX orm_resources_first_coin_number_idx ON public.orm_resources USING btree ((((metadata -> 'coin_number'::text) -> 0)));
 7   DROP INDEX public.orm_resources_first_coin_number_idx;
       public            figgy_staging    false    238    238                       1259    8246957 #   orm_resources_first_find_number_idx    INDEX     �   CREATE INDEX orm_resources_first_find_number_idx ON public.orm_resources USING btree ((((metadata -> 'find_number'::text) -> 0)));
 7   DROP INDEX public.orm_resources_first_find_number_idx;
       public            figgy_staging    false    238    238                       1259    8246958 $   orm_resources_first_issue_number_idx    INDEX     �   CREATE INDEX orm_resources_first_issue_number_idx ON public.orm_resources USING btree ((((metadata -> 'issue_number'::text) -> 0)));
 8   DROP INDEX public.orm_resources_first_issue_number_idx;
       public            figgy_staging    false    238    238                       1259    8246959 +   preservation_object_preserved_object_id_idx    INDEX     �   CREATE INDEX preservation_object_preserved_object_id_idx ON public.orm_resources USING btree (((((metadata -> 'preserved_object_id'::text) -> 0) -> 'id'::text))) WHERE ((internal_resource)::text = 'PreservationObject'::text);
 ?   DROP INDEX public.preservation_object_preserved_object_id_idx;
       public            figgy_staging    false    238    238    238                       1259    8246960    preserved_object_id_idx    INDEX     �   CREATE INDEX preserved_object_id_idx ON public.orm_resources USING btree ((((((metadata -> 'preserved_object_id'::text) -> 0) ->> 'id'::text))::uuid));
 +   DROP INDEX public.preserved_object_id_idx;
       public            figgy_staging    false    238    238                       1259    8246961    resource_id_idx    INDEX     �   CREATE INDEX resource_id_idx ON public.orm_resources USING btree ((((((metadata -> 'resource_id'::text) -> 0) ->> 'id'::text))::uuid));
 #   DROP INDEX public.resource_id_idx;
       public            figgy_staging    false    238    238                       1259    8246962    source_metadata_identifier_idx    INDEX     �   CREATE INDEX source_metadata_identifier_idx ON public.orm_resources USING btree (((metadata ->> 'source_metadata_identifier'::text)));
 2   DROP INDEX public.source_metadata_identifier_idx;
       public            figgy_staging    false    238    238                       1259    8246963 
   test_idx_1    INDEX     �   CREATE INDEX test_idx_1 ON public.orm_resources USING btree ((((((metadata -> 'resource_id'::text) -> 0) ->> 'id'::text))::uuid));
    DROP INDEX public.test_idx_1;
       public            figgy_staging    false    238    238                       1259    8246964 
   test_idx_2    INDEX     �   CREATE INDEX test_idx_2 ON public.orm_resources USING btree ((((((metadata -> 'preserved_object_id'::text) -> 0) ->> 'id'::text))::uuid));
    DROP INDEX public.test_idx_2;
       public            figgy_staging    false    238    238            ,           2606    4788899     ocr_requests fk_rails_712a4527c4    FK CONSTRAINT        ALTER TABLE ONLY public.ocr_requests
    ADD CONSTRAINT fk_rails_712a4527c4 FOREIGN KEY (user_id) REFERENCES public.users(id);
 J   ALTER TABLE ONLY public.ocr_requests DROP CONSTRAINT fk_rails_712a4527c4;
       public          figgy_staging    false    3369    245    236            +           2606    4788904 2   active_storage_variant_records fk_rails_993965df05    FK CONSTRAINT     �   ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);
 \   ALTER TABLE ONLY public.active_storage_variant_records DROP CONSTRAINT fk_rails_993965df05;
       public          figgy_staging    false    3301    217    219            *           2606    4788909 .   active_storage_attachments fk_rails_c3b3935057    FK CONSTRAINT     �   ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);
 X   ALTER TABLE ONLY public.active_storage_attachments DROP CONSTRAINT fk_rails_c3b3935057;
       public          figgy_staging    false    217    3301    215           