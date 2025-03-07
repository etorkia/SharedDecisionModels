using Distributions, DataFrames, Statistics

#############################
# Model Setup and Functions #
#############################

# Define strategies
const COOPERATE = :cooperate  # free trade: no tariff
const DEFECT = :defect     # impose tariff

# Define the triangular distribution for tariff rates: min=5, mode=20, max=30.
tri_dist = TriangularDist(10.0, 50.0, 25.0)

# TradeData struct holds bilateral trade data (in billions of dollars)
struct TradeData
    exports::Float64  # US exports (to partner)
    imports::Float64  # US imports (from partner)
end

# Example baseline trade data (replace with current figures as needed)
const trade_data = Dict(
    "Canada" => TradeData(250.0, 300.0),
    "Mexico" => TradeData(200.0, 350.0),
    "China" => TradeData(130.0, 450.0),
    "Japan" => TradeData(60.0, 140.0),
    "European Union" => TradeData(376.0, 545.0)
)

# GDP data (in billions of dollars) datacommons.org
const gdp_data = Dict(
    "US" => 27700.0,
    "Canada" => 2200.0,
    "Mexico" => 1790.0,
    "China" => 17800.0,
    "Japan" => 4200.0,
    "European Union" => 18600.0
)

# Normalization factor to scale down trade volumes
const normalization_factor = 100.0

# --- Tariff assumptions ---
# - If opponent cooperated last round: 20% chance to defect, 80% chance to cooperate.
# - If opponent defected last round: 80% chance to defect, 20% chance to cooperate.
# - When a party defects, an effective tariff rate is sampled from a triangular distribution (min=5%, mode=20%, max=30%).
# - Payoffs (scaled by normalized trade volume = trade volume / normalization_factor):
#     * Mutual cooperation: 3x normalized trade volume.
#     * One defects, the other cooperates: defector gets 5x normalized trade volume; cooperator gets 0.
#     * Mutual defection: 1x normalized trade volume.

# Define a scaled payoff function.
function scaled_payoff(strategy_player, strategy_opponent, trade_volume)
    norm_trade_volume = trade_volume / normalization_factor
    if strategy_player == COOPERATE && strategy_opponent == COOPERATE
        return 3 * norm_trade_volume
    elseif strategy_player == COOPERATE && strategy_opponent == DEFECT
        return 0.0 * norm_trade_volume
    elseif strategy_player == DEFECT && strategy_opponent == COOPERATE
        return 5 * norm_trade_volume
    elseif strategy_player == DEFECT && strategy_opponent == DEFECT
        return 1 * norm_trade_volume
    end
end

# Simulate one bilateral round between the US and a specific partner.
function simulate_round(trade_info::TradeData, us_strategy, partner_strategy)
    trade_volume = trade_info.imports  # use US imports as proxy for trade volume
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

###########################################################
# Simulation Function: One dynamic simulation run
###########################################################
"""
simulate_trade_war_run(rounds::Int)

Runs a dynamic simulation (over a specified number of rounds) of the US trading with each partner.
Returns a named tuple with:
 - us_total: overall US cumulative payoff,
 - us_by_country: dictionary of US cumulative payoff by partner,
 - partner_scores: dictionary of partner cumulative payoffs,
 - avg_tariff_US: dictionary of average effective tariff rates faced by the US (per partner),
 - avg_tariff_Partner: dictionary of average effective tariff rates faced by the partner,
 - impact_US: dictionary of US impact on GDP (percentage) per partner,
 - impact_Partner: dictionary of partner impact on GDP (percentage) per partner,
 - overall_US_avg_tariff: overall average effective tariff rate faced by the US across all partners,
 - overall_US_impact: overall US impact on GDP (percentage).
"""
function simulate_trade_war_run(rounds::Int)
    partners = collect(keys(trade_data))
    us_total = 0.0
    us_cumulative = Dict{String,Float64}()
    partner_totals = Dict{String,Float64}()

    # For accumulating tariff rates.
    tariff_US = Dict{String,Float64}()
    tariff_Partner = Dict{String,Float64}()

    # Initialize history and payoffs for each partner.
    prev_us_actions = Dict{String,Symbol}()
    prev_partner_actions = Dict{String,Symbol}()
    for partner in partners
        us_cumulative[partner] = 0.0
        partner_totals[partner] = 0.0
        tariff_US[partner] = 0.0
        tariff_Partner[partner] = 0.0
        prev_us_actions[partner] = COOPERATE
        prev_partner_actions[partner] = COOPERATE
    end

    # Run simulation rounds.
    for r in 1:rounds
        for partner in partners
            # Choose strategies based on previous actions.
            us_strategy = choose_strategy(prev_partner_actions[partner])
            partner_strategy = choose_strategy(prev_us_actions[partner])

            # Determine effective tariff rates:
            # For US: if partner defects, US faces a tariff.
            us_eff_tariff = partner_strategy == DEFECT ? rand(tri_dist) : 0.0
            # For Partner: if US defects, partner faces a tariff.
            partner_eff_tariff = us_strategy == DEFECT ? rand(tri_dist) : 0.0

            # Accumulate tariff rates.
            tariff_US[partner] += us_eff_tariff
            tariff_Partner[partner] += partner_eff_tariff

            # Simulate the round.
            us_pay, part_pay = simulate_round(trade_data[partner], us_strategy, partner_strategy)
            us_total += us_pay
            us_cumulative[partner] += us_pay
            partner_totals[partner] += part_pay

            # Update history.
            prev_us_actions[partner] = us_strategy
            prev_partner_actions[partner] = partner_strategy
        end
    end

    # Compute average tariff rates per round for each partner.
    avg_tariff_US = Dict(partner => tariff_US[partner] / rounds for partner in partners)
    avg_tariff_Partner = Dict(partner => tariff_Partner[partner] / rounds for partner in partners)

    # Compute impact on GDP (as a percentage) using gdp_data.
    impact_US = Dict(partner => (us_cumulative[partner] / gdp_data["US"]) * 100 for partner in partners)
    impact_Partner = Dict(partner => (partner_totals[partner] / gdp_data[partner]) * 100 for partner in partners)

    # Compute overall US impact as percentage of US GDP.
    overall_US_impact = (us_total / gdp_data["US"]) * 100
    # Compute overall US average tariff as the mean of the per-partner average tariff rates.
    overall_US_avg_tariff = mean(collect(values(avg_tariff_US)))

    return (us_total=us_total,
        us_by_country=us_cumulative,
        partner_scores=partner_totals,
        avg_tariff_US=avg_tariff_US,
        avg_tariff_Partner=avg_tariff_Partner,
        impact_US=impact_US,
        impact_Partner=impact_Partner,
        overall_US_avg_tariff=overall_US_avg_tariff,
        overall_US_impact=overall_US_impact)
end

###########################################
# Monte Carlo Simulation and DataFrame
###########################################
"""
run_monte_carlo(n_runs::Int, rounds::Int)

Repeats the dynamic simulation n_runs times. For each run, extracts the outcomes
and stores them in a DataFrame.
"""
function run_monte_carlo(n_runs::Int, rounds::Int)
    results = Vector{NamedTuple}()
    partners = collect(keys(trade_data))

    for run in 1:n_runs
        sim = simulate_trade_war_run(rounds)
        # Build a named tuple for this simulation run.
        nt = (; run=run,
            us_total=sim.us_total,
            overall_US_avg_tariff=sim.overall_US_avg_tariff,
            overall_US_impact=sim.overall_US_impact)
        # For each partner, add fields.
        for partner in partners
            nt = merge(nt, (
                Symbol("US_" * partner * "_payoff") => sim.us_by_country[partner],
                Symbol("Partner_" * partner * "_payoff") => sim.partner_scores[partner],
                Symbol("US_" * partner * "_avg_tariff") => sim.avg_tariff_US[partner],
                Symbol("Partner_" * partner * "_avg_tariff") => sim.avg_tariff_Partner[partner],
                Symbol("US_" * partner * "_impact") => sim.impact_US[partner],
                Symbol("Partner_" * partner * "_impact") => sim.impact_Partner[partner]
            ))
        end
        push!(results, nt)
    end

    return DataFrame(results)
end

###########################################
# Run Monte Carlo and Analyze Results
###########################################
# Settings:
n_simulations = 10_000  # number of Monte Carlo runs
rounds_per_run = 5  # number of rounds per simulation

# Run the Monte Carlo simulation.
@time df_results = run_monte_carlo(n_simulations, rounds_per_run)

# Display the first few rows of the results DataFrame.
println("Monte Carlo Simulation Results (first 10 runs):")
first(df_results, 10) |> display

# Analyze overall US cumulative payoff distribution.
println("\nSummary statistics for overall US cumulative payoff:")
describe(df_results.us_total) |> display

# Analyze overall average tariff rate faced by the US.
println("\nSummary statistics for overall US average tariff rate:")
describe(df_results.overall_US_avg_tariff) |> display

# Analyze overall US impact on GDP.
println("\nSummary statistics for overall US impact on GDP (%):")
describe(df_results.overall_US_impact) |> display
