# Define strategies
const COOPERATE = :cooperate  # free trade: no tariff
const DEFECT = :defect     # impose tariff

# TradeData struct holds bilateral trade data (in billions of dollars)
struct TradeData
    exports::Float64  # US exports (to partner)
    imports::Float64  # US imports (from partner)
end

# Example baseline trade data (replace with current figures as needed)
trade_data = Dict(
    "Canada" => TradeData(250.0, 300.0),
    "Mexico" => TradeData(200.0, 350.0),
    "China" => TradeData(130.0, 450.0),
    "Japan" => TradeData(60.0, 140.0),
    "Germany" => TradeData(70.0, 100.0)
)

# GDP data (in billions of dollars)
gdp_data = Dict(
    "US" => 21000.0,
    "Canada" => 1740.0,
    "Mexico" => 1270.0,
    "China" => 17700.0,
    "Japan" => 5150.0,
    "Germany" => 4000.0
)

# Normalization factor to scale down trade volumes
normalization_factor = 100.0

# Define a scaled payoff function.
# The payoffs follow a prisoner's dilemma structure scaled by the (normalized) trade volume.
#   - Mutual cooperation: 3 × (normalized trade volume)
#   - One defects, the other cooperates: defector gets 5 × (normalized trade volume); cooperator gets 0.
#   - Mutual defection: 1 × (normalized trade volume).
function scaled_payoff(strategy_player, strategy_opponent, trade_volume)
    norm_trade_volume = trade_volume / normalization_factor
    if strategy_player == COOPERATE && strategy_opponent == COOPERATE
        return 3 * norm_trade_volume
    elseif strategy_player == COOPERATE && strategy_opponent == DEFECT
        return 0 * norm_trade_volume
    elseif strategy_player == DEFECT && strategy_opponent == COOPERATE
        return 5 * norm_trade_volume
    elseif strategy_player == DEFECT && strategy_opponent == DEFECT
        return 1 * norm_trade_volume
    end
end

# Simulate one bilateral round between the US and a specific partner.
function simulate_round(trade_info::TradeData, us_strategy, partner_strategy)
    # Use US import value as trade volume proxy
    trade_volume = trade_info.imports
    us_pay = scaled_payoff(us_strategy, partner_strategy, trade_volume)
    partner_pay = scaled_payoff(partner_strategy, us_strategy, trade_volume)
    return us_pay, partner_pay
end

# Define a strategy choice function that reacts to the opponent's previous action.
function choose_strategy(prev_opponent_action::Symbol)
    if prev_opponent_action == COOPERATE
        return rand() < 0.2 ? DEFECT : COOPERATE
    else  # previous action was DEFECT
        return rand() < 0.8 ? DEFECT : COOPERATE
    end
end

# Simulate a repeated game with counter-tariff behavior,
# tracking both the overall US payoff and the payoff breakdown per partner.
function simulate_trade_war_by_country(rounds::Int)
    partners = collect(keys(trade_data))
    us_total = 0.0
    us_cumulative = Dict{String,Float64}()
    partner_totals = Dict{String,Float64}()

    # Initialize history and payoff dictionaries for each partner.
    prev_us_actions = Dict{String,Symbol}()
    prev_partner_actions = Dict{String,Symbol}()
    for partner in partners
        us_cumulative[partner] = 0.0
        partner_totals[partner] = 0.0
        prev_us_actions[partner] = COOPERATE
        prev_partner_actions[partner] = COOPERATE
    end

    for round in 1:rounds
        for partner in partners
            us_strategy = choose_strategy(prev_partner_actions[partner])
            partner_strategy = choose_strategy(prev_us_actions[partner])
            us_pay, part_pay = simulate_round(trade_data[partner], us_strategy, partner_strategy)
            us_total += us_pay
            us_cumulative[partner] += us_pay
            partner_totals[partner] += part_pay
            prev_us_actions[partner] = us_strategy
            prev_partner_actions[partner] = partner_strategy
        end
    end

    return us_total, us_cumulative, partner_totals
end

# Run the simulation for a specified number of rounds.
rounds = 3
us_total, us_by_country, partner_scores = simulate_trade_war_by_country(rounds)

println("After $rounds rounds (with normalization factor = $(normalization_factor)):")
println("Overall US cumulative payoff (normalized, 'billion-dollar units'): $(round(us_total, digits=2))")
println("\nUS cumulative payoff by country:")
for (partner, score) in us_by_country
    println(" - $partner: $(round(score, digits=2))")
end
# Total US payoff across all partners:
total_us_by_country = sum(values(us_by_country))
println("Total US cumulative payoff (sum over all partners): $(round(total_us_by_country, digits=2))")

println("\nPartner cumulative payoff:")
for (partner, score) in partner_scores
    println(" - $partner: $(round(score, digits=2))")
end
# Total partner payoff across all partners:
total_partner_payoff = sum(values(partner_scores))
println("Total partner cumulative payoff (sum over all partners): $(round(total_partner_payoff, digits=2))")

# Calculate the impact as a percentage of GDP for each country.
println("\nEstimated percentage impact on GDP per country:")
for partner in keys(trade_data)
    us_percent_impact = (us_by_country[partner] / gdp_data["US"]) * 100
    partner_percent_impact = (partner_scores[partner] / gdp_data[partner]) * 100
    println(" - US impact (with $partner): $(round(us_percent_impact, digits=4))% of US GDP")
    println(" - $partner impact (with US): $(round(partner_percent_impact, digits=4))% of $partner GDP")
end

# Total impact for the US across all 5 partners as a percentage of US GDP:
overall_us_percent_impact = (us_total / gdp_data["US"]) * 100
println("\nTotal US impact across all partners: $(round(overall_us_percent_impact, digits=4))% of US GDP")
