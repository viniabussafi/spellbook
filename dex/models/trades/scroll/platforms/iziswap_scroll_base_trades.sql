{{
    config(
        schema = 'iziswap_scroll',
        alias = 'base_trades',
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['tx_hash', 'evt_index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{% set iziswap_start_date = "2023-10-13" %}

SELECT
    'scroll' AS blockchain
    , 'iziswap' AS project
    , contract_address AS project_contract_address
    , '1' AS version
    , evt_tx_hash AS tx_hash
    , evt_index
    , evt_block_time AS block_time
    , evt_block_number AS block_number
    , CAST(DATE_TRUNC('month', evt_block_time) AS DATE) AS block_month
    , CAST(DATE_TRUNC('day', evt_block_time) AS DATE) AS block_date
    , CASE WHEN sellXEarnY THEN tokenY ELSE tokenX END AS token_bought_address 
    , CASE WHEN sellXEarnY THEN tokenX ELSE tokenY END AS token_sold_address
    , CASE WHEN sellXEarnY THEN amountY ELSE amountX END AS token_bought_amount_raw 
    , CASE WHEN sellXEarnY THEN amountX ELSE amountY END AS token_sold_amount_raw
    , CAST(evt_tx_from AS VARBINARY) AS taker
    , CAST(evt_tx_to AS VARBINARY) AS maker
FROM {{ source('iziswap_scroll', 'iZiSwapPool_evt_Swap') }}
{% if is_incremental() %}
WHERE {{incremental_predicate('evt_block_time')}}
{% else %}
WHERE evt_block_time >= TIMESTAMP '{{iziswap_start_date}}'
{% endif %}

