graph TD
    subgraph Data Ingestion
        A[Data Sources: Databases, APIs, Logs] -- Stream/Batch --> B(Raw Data on Amazon S3)
    end

    subgraph Data Processing (AWS Glue)
        B -- Triggered by new files --> C(AWS Glue ETL Job)
        C -- Reads raw data --> B
        C -- Writes transformed data --> D(Curated Data in S3, optimized as Parquet)
    end

    subgraph Metadata Catalog
        D -- Scanned by --> E(AWS Glue Crawler)
        E -- Updates --> F(AWS Glue Data Catalog)
    end

    subgraph Analytics (Amazon Redshift)
        G[Redshift Cluster] -- External Schema (References) --> F
        G -- Queries --> G
    end
    
    subgraph Querying with Redshift Spectrum
        G -- Joins/Queries Data in S3 --> H[Redshift Spectrum]
        H -- Retrieves Data --> D
        G -- Retrieves Data --> D
    end

    style G fill:#f9f,stroke:#333,stroke-width:2px;
    style H fill:#f9f,stroke:#333,stroke-width:2px;
    style F fill:#9f9,stroke:#333,stroke-width:2px;
    style B fill:#9f9,stroke:#333,stroke-width:2px;
    style D fill:#9f9,stroke:#333,stroke-width:2px;
