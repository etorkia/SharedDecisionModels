using Distributions

# Define strategies
const COOPERATE = :cooperate  # free trade: no tariff
const DEFECT = :defect     # impose tariff

# Define the triangular distribution for tariff rates: min=5, mode=20, max=30.
tri_dist = TriangularDist(10.0, 30.0, 20.0)

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

# Print tariff assumptions
println("Tariff assumptions:")
println(" - If opponent cooperated last round: 20% chance to defect (impose tariff), 80% to cooperate (free trade).")
println(" - If opponent defected last round: 80% chance to defect, 20% to cooperate.")
println(" - Effective tariff rate when a party defects is sampled from a triangular distribution:")
println("     min = 5%, mode = 20%, max = 30%")
println(" - Payoffs (scaled by normalized trade volume = trade volume / $(normalization_factor)):")
println("    * Mutual cooperation: 3x normalized trade volume")
println("    * One defects while the other cooperates: defector gets 5x normalized trade volume; cooperator gets 0.")
println("    * Mutual defection: 1x normalized trade volume\n")

# Define a scaled payoff function.
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
    # Use US import value as trade volume proxy.
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
# printing the details of each tariff round including the effective tariff rate.
function simulate_trade_war_by_country(rounds::Int)
    partners = collect(keys(trade_data))
    us_total = 0.0
    us_cumulative = Dict{String,Float64}()
    partner_totals = Dict{String,Float64}()

    # Dictionaries to accumulate effective tariff rates over rounds for averaging.
    effective_tariff_US = Dict{String,Float64}()
    effective_tariff_Partner = Dict{String,Float64}()

    # Initialize history and payoff dictionaries for each partner.
    prev_us_actions = Dict{String,Symbol}()
    prev_partner_actions = Dict{String,Symbol}()
    for partner in partners
        us_cumulative[partner] = 0.0
        partner_totals[partner] = 0.0
        effective_tariff_US[partner] = 0.0
        effective_tariff_Partner[partner] = 0.0
        prev_us_actions[partner] = COOPERATE
        prev_partner_actions[partner] = COOPERATE
    end

    for r in 1:rounds
        println("\n--- Round $r ---")
        for partner in partners
            println("\nPartner: $partner")
            println("Previous actions: US = $(prev_us_actions[partner]), $partner = $(prev_partner_actions[partner])")

            # Choose strategies based on the opponent's previous move.
            us_strategy = choose_strategy(prev_partner_actions[partner])
            partner_strategy = choose_strategy(prev_us_actions[partner])

            println("Chosen strategies: US -> $(us_strategy), $partner -> $(partner_strategy)")

            # Determine effective tariff rates for this round:
            # For the US: if partner defects, then partner imposes a tariff on US goods.
            us_eff_tariff = partner_strategy == DEFECT ? rand(tri_dist) : 0.0
            # For the partner: if US defects, then US imposes a tariff on partner goods.
            partner_eff_tariff = us_strategy == DEFECT ? rand(tri_dist) : 0.0
            println("Effective tariff rates this round: US faces $(round(us_eff_tariff, digits=2))% from $partner, $partner faces $(round(partner_eff_tariff, digits=2))% from US")

            # Accumulate tariff rates for averaging.
            effective_tariff_US[partner] += us_eff_tariff
            effective_tariff_Partner[partner] += partner_eff_tariff

            # Simulate the round for this bilateral interaction.
            us_pay, part_pay = simulate_round(trade_data[partner], us_strategy, partner_strategy)
            println("Round payoff: US = $(round(us_pay, digits=2)), $partner = $(round(part_pay, digits=2))")

            # Update cumulative totals.
            us_total += us_pay
            us_cumulative[partner] += us_pay
            partner_totals[partner] += part_pay

            # Update history for the next round.
            prev_us_actions[partner] = us_strategy
            prev_partner_actions[partner] = partner_strategy

            println("Cumulative totals for $partner: US = $(round(us_cumulative[partner], digits=2)), $partner = $(round(partner_totals[partner], digits=2))")
        end
    end

    return us_total, us_cumulative, partner_totals, effective_tariff_US, effective_tariff_Partner
end

# Run the simulation for a specified number of rounds.
rounds = 5
us_total, us_by_country, partner_scores, effective_tariff_US, effective_tariff_Partner = simulate_trade_war_by_country(rounds)

println("\nAfter $rounds rounds (with normalization factor = $(normalization_factor)):")
println("Overall US cumulative payoff (normalized, 'billion-dollar units'): $(round(us_total, digits=2))")
println("\nUS cumulative payoff by country:")
for (partner, score) in us_by_country
    println(" - $partner: $(round(score, digits=2))")
end
total_us_by_country = sum(values(us_by_country))
println("Total US cumulative payoff (sum over all partners): $(round(total_us_by_country, digits=2))")

println("\nPartner cumulative payoff:")
for (partner, score) in partner_scores
    println(" - $partner: $(round(score, digits=2))")
end
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

overall_us_percent_impact = (us_total / gdp_data["US"]) * 100
println("\nTotal US impact across all partners: $(round(overall_us_percent_impact, digits=4))% of US GDP")

# Calculate and print the average effective tariff rate per round for each bilateral relationship.
println("\nAverage effective tariff rates per round:")
for partner in keys(trade_data)
    avg_us_tariff = effective_tariff_US[partner] / rounds
    avg_partner_tariff = effective_tariff_Partner[partner] / rounds
    println(" - US facing $partner: $(round(avg_us_tariff, digits=2))% per round on average")
    println(" - $partner facing US: $(round(avg_partner_tariff, digits=2))% per round on average")
end
