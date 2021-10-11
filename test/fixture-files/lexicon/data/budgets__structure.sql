DROP TABLE IF EXISTS master_budgets;

        CREATE TABLE master_budgets (
          activity_family character varying NOT NULL,
          budget_category character varying NOT NULL,
          variant character varying NOT NULL,
          mode character varying,
          proportionnal_key character varying,
          repetition integer NOT NULL,
          frequency character varying NOT NULL,
          start_month integer NOT NULL,
          quantity numeric(8,2) NOT NULL,
          unit_pretax_amount numeric(8,2) NOT NULL,
          tax_rate numeric(8,2) NOT NULL,
          unit character varying NOT NULL,
          direction character varying NOT NULL
        );
        CREATE INDEX master_budgets_variant ON master_budgets(variant);
