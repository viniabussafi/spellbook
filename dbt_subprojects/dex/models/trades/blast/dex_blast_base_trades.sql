{{ config(
    schema = 'dex_blast'
    , alias = 'base_trades'
    , materialized = 'view'
    )
}}

{% set base_models = [
    ref('uniswap_v4_blast_base_trades')
    , ref('uniswap_v3_blast_base_trades')
    , ref('uniswap_v2_blast_base_trades')
    , ref('blasterswap_blast_base_trades')
    , ref('thruster_blast_base_trades')
    , ref('fenix_blast_base_trades')
    , ref('dackieswap_v2_blast_base_trades')
    , ref('sushiswap_v2_blast_base_trades')
    , ref('dackieswap_v3_blast_base_trades')
    , ref('swapblast_blast_base_trades')
    , ref('dyorswap_blast_base_trades')
    , ref('icecreamswap_v2_blast_base_trades')
] %}

WITH base_union AS (
    SELECT *
    FROM (
        {% for base_model in base_models %}
        SELECT
            blockchain
            , project
            , version
            , block_month
            , block_date
            , block_time
            , block_number
            , token_bought_amount_raw
            , token_sold_amount_raw
            , token_bought_address
            , token_sold_address
            , taker
            , maker
            , project_contract_address
            , tx_hash
            , evt_index
        FROM
            {{ base_model }}
        {% if not loop.last %}
        UNION ALL
        {% endif %}
        {% endfor %}
    )
)

{{
    add_tx_columns(
        model_cte = 'base_union'
        , blockchain = 'blast'
        , columns = ['from', 'to', 'index']
    )
}}
