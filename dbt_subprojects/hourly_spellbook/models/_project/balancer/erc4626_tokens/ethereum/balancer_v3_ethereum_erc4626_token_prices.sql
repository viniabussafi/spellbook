{{ config(
        schema = 'balancer_v3_ethereum',
        alias = 'erc4626_token_prices',
        materialized = 'table',
        file_format = 'delta'
    )
}}

WITH wrap_unwrap AS(
        SELECT 
            evt_block_time,
            wrappedToken,
            CAST(depositedUnderlying AS DOUBLE) / CAST(mintedShares AS DOUBLE) AS ratio
        FROM {{ source('balancer_v3_ethereum', 'Vault_evt_Wrap') }}

        UNION ALL

        SELECT 
            evt_block_time,
            wrappedToken, 
            CAST(withdrawnUnderlying AS DOUBLE) / CAST(burnedShares AS DOUBLE) AS ratio
        FROM {{ source('balancer_v3_ethereum', 'Vault_evt_Unwrap') }}        
    ),


    price_join AS(
    SELECT 
        w.evt_block_time,
        m.underlying_token,
        w.wrappedToken,
        m.erc4626_token_symbol,
        m.underlying_token_symbol,
        m.decimals,
        ratio * price AS adjusted_price
    FROM wrap_unwrap w
    JOIN {{ref('balancer_v3_ethereum_erc4626_token_mapping')}} m ON m.erc4626_token = w.wrappedToken
    JOIN {{ source('prices', 'usd') }} p ON m.underlying_token = p.contract_address
    AND p.blockchain = 'ethereum'
    AND DATE_TRUNC('minute', w.evt_block_time) = DATE_TRUNC('minute', p.minute)         
    )

SELECT
    p.evt_block_time AS minute,
    'ethereum' AS blockchain,
    wrappedToken AS wrapped_token,
    underlying_token,
    erc4626_token_symbol,
    underlying_token_symbol,
    decimals,
    APPROX_PERCENTILE(adjusted_price, 0.5) AS median_price,
    LEAD(p.evt_block_time, 1, CURRENT_DATE + INTERVAL '1' day) OVER (PARTITION BY wrappedToken ORDER BY p.evt_block_time) AS next_change
FROM price_join p
GROUP BY 1, 2, 3, 4, 5, 6, 7